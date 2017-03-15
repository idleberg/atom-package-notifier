meta = require "../package.json"

# Dependencies
{CompositeDisposable} = require "atom"

module.exports = PackageNotifier =
  config:
    runAtLaunch:
      title: "Run at Startup"
      description: "Check for new packages when Atom launches"
      type: 'boolean'
      default: true
      order: 0
    delayStartup:
      title: "Delay Startup"
      description: "Seconds until the check for new packages first runs (minimum: 5, maximum: 60)"
      type: 'integer'
      default: 10
      minimum: 5
      maximum: 60
      order: 1
    updateInterval:
      title: "Update Interval"
      description: "Minutes until the next check for new packages runs (maximum: 1140)"
      type: 'integer'
      default: 15
      minimum: 1
      maximum: 1140
      order: 2
    maximumPackages:
      title: "Maximum Packages"
      description: "Limit the number of notifications displayed (maximum: 45)"
      type: 'integer'
      default: 6
      minimum: 1
      maximum: 45
      order: 3
    dismissNotifications:
      title: "Dismiss Notifications"
      description: "Automatically dismiss the update notifications after 5 seconds"
      type: "boolean"
      default: false
      order: 4
    suppressError:
      title: "Suppress Errors"
      description: "Don't show error notifications, errors will be shown in the console instead"
      type: "boolean"
      default: false
      order: 5
  subscriptions: null

  activate: ->
    # Events subscribed to in atom"s system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add "atom-workspace", "package-notifier:show-latest-packages": => @getFeed(true)

    # Delay execution
    delayStartup = atom.config.get("#{meta.name}.delayStartup") * 1000
    setTimeout =>
      @getFeed() if atom.config.get("#{meta.name}.runAtLaunch")

      updateInterval = atom.config.get("#{meta.name}.updateInterval") * 1000 * 60
      window.setInterval(@getFeed, updateInterval)
    , delayStartup
    

  deactivate: ->
    @subscriptions?.dispose()
    @subscriptions = null

  getFeed: (forceNotifications = false) ->
    FeedParser = require('feedparser')
    request = require('request')

    packageFeed = request('https://atom.io/packages.atom')
    feedparser = new FeedParser
    d = new Date
    packageCounter = 0

    packageFeed.on 'error', (error) ->
      if atom.config.get("#{meta.name}.suppressError") isnt true
        return atom.notifications.addError(
          meta.name,
          detail: error
          dismissable: true
        )
      else
        return console.error error

    packageFeed.on 'response', (res) ->
      stream = this
      if res.statusCode != 200
        @emit 'error', new Error('Bad status code')
      else
        stream.pipe feedparser
      return

    feedparser.on 'error', (error) ->
      if atom.config.get("#{meta.name}.suppressError") isnt true
        return atom.notifications.addError(
          meta.name,
          detail: error
          dismissable: true
        )
      else
        return console.error error

    feedparser.on 'readable', ->
      stream = this
      item = undefined
      lastUpdateTime = localStorage.getItem("#{meta.name}.lastUpdateTime") || 0
      maximumPackages = atom.config.get("#{meta.name}.maximumPackages")

      while item = stream.read()
        packageCounter++
        
        if packageCounter > maximumPackages
          localStorage.setItem("#{meta.name}.lastUpdateTime", d.getTime().toString())
          break

        if forceNotifications is true or Date.parse(item.pubDate) > lastUpdateTime
          atom.notifications.addInfo(
            "**[#{item.title}](#{item.link})** by [#{item.author}](https://atom.io/users/#{item.author})",
            dismissable: !atom.config.get("#{meta.name}.dismissNotifications")
          )
      return
