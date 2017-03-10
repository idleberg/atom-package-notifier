meta = require "../package.json"

# Dependencies
{CompositeDisposable} = require "atom"
FeedParser = require('feedparser')
request = require('request')

module.exports = PackageNotifier =
  config:
    runAtLaunch:
      description: "Check for new packages when Atom launches"
      type: 'boolean'
      default: true
      order: 0
    updateInterval:
      description: "Minutes until the next check for new packages runs"
      type: 'integer'
      default: 15
      minimum: 1
      maximum: 1140
      order: 1
    maximumItems:
      title: "Maximum Packages"
      description: "Limit the number of notifications displayed"
      type: 'integer'
      default: 6
      minimum: 1
      maximum: 45
      order: 2
    dismissNotification:
      title: "Dismiss Notification"
      description: "Automatically dismiss the update notification after 5 seconds"
      type: "boolean"
      default: false
      order: 3
  subscriptions: null

  activate: ->
    # Events subscribed to in atom"s system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add "atom-workspace", "package-notifier:show-latest-packages": => @getFeed(true)

    @getFeed() if atom.config.get("#{meta.name}.runAtLaunch")

    updateInterval = atom.config.get("#{meta.name}.updateInterval") * 1000 * 60
    window.setInterval(@getFeed, updateInterval)

  deactivate: ->
    @subscriptions?.dispose()
    @subscriptions = null

  getFeed: (forceNotifications = false)->
    packageFeed = request('https://atom.io/packages.atom')
    feedparser = new FeedParser
    d = new Date
    packageCounter = 0

    packageFeed.on 'error', (error) ->
      return atom.notifications.addError(
        meta.name,
        detail: error
        dismissable: true
      )
      return

    packageFeed.on 'response', (res) ->
      stream = this
      if res.statusCode != 200
        @emit 'error', new Error('Bad status code')
      else
        stream.pipe feedparser
      return

    feedparser.on 'error', (error) ->
      return atom.notifications.addError(
        meta.name,
        detail: error
        dismissable: true
      )

    feedparser.on 'readable', ->
      stream = this
      item = undefined
      lastUpdateTime = localStorage.getItem("#{meta.name}.lastUpdateTime") || 0
      maximumItems = atom.config.get("#{meta.name}.maximumItems")

      while item = stream.read()
        packageCounter++
        
        if packageCounter > maximumItems
          localStorage.setItem("#{meta.name}.lastUpdateTime", d.getTime().toString())
          break

        if forceNotifications is true or Date.parse(item.pubDate) > lastUpdateTime
          atom.notifications.addInfo(
            "**[#{item.title}](#{item.link})** by [#{item.author}](https://atom.io/users/#{item.author})",
            dismissable: !atom.config.get("#{meta.name}.dismissNotification")
          )
      return
