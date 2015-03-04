#! /usr/bin/env coffee

config = require('./config')
Twitter = require('twitter')
sqlite3 = require('sqlite3').verbose()
chalk = require('chalk')
program = require('commander')
fs = require('fs')
db = new (sqlite3.Database)('folloshr.sqlite')
_ = require('underscore')

client = new Twitter(
  consumer_key: config.consumer_key
  consumer_secret: config.consumer_secret
  access_token_key: config.access_token_key
  access_token_secret: config.access_token_secret)

getUser = (fn) ->
  client.get 'account/settings', {}, (err, user, response) =>
    fn(user)


search = (keyword) ->
  console.log("arama: #{chalk.cyan(keyword)}")
  client.get 'search/tweets', {q: keyword, count: 100}, (err, items, response) ->
    throw err if err
    _.each items.statuses, (item) ->
      follow(item)

listen_stream = (keyword) ->
  stream_count = 0
  client.stream 'statuses/filter', { track: keyword }, (stream) ->
    stream.on 'data', (tweet) ->
      console.log "#{chalk.yellow(tweet.user.screen_name)} #{chalk.cyan(tweet.text)}"
      stream_count++
      if stream_count == program.follow
        process.exit 1
      if tweet.lang == program.lang and tweet.user.id
        follow tweet
    stream.on 'error', (error) ->
      throw error

follow = (item) ->
  query = 'SELECT user_id FROM followings WHERE user_id=\'' + item.user.id + '\''
  db.serialize ->
    db.get query, (err, row) ->
      throw err if err

      if typeof row == 'undefined'
        client.post 'friendships/create', { user_id: item.user.id }, (error, follow, response) ->
          throw error if error

          db.run 'INSERT INTO followings(user_id) VALUES(?)', item.user.id, ->
            console.log "#{item.user.screen_name} #{chalk.green('following')}"

unfollow = (user) ->
  db.serialize ->
    countQuery = 'SELECT COUNT(user_id) AS count FROM followings WHERE unfollowed_at IS NULL'
    db.each countQuery, (err, row) ->
      count = row.count
      max = 50
      parts = if count > max
        Math.ceil count / max
      else
        1
      console.log parts

      unfollowLoop = (i) ->
        console.log "#{i} running"
        query = "SELECT user_id FROM followings WHERE unfollowed_at IS NULL LIMIT #{i * parts}, #{max} "
        db.map query, (err, map) ->
          user_ids = _.map map, (val, key) ->
            key
          user_ids = user_ids.join()

          setTimeout ->
            console.log "timer: #{i}"
            client.get 'friendships/lookup', {user_id: user_ids}, (err, items, response) ->
              console.log err
              throw "lookup: #{err}" if err
              _i = 0
              for item in items
                if _.contains(item.connections, 'followed_by')
                  console.log "#{item.screen_name} seni #{chalk.green('takip ediyor')}"
                else
                  setTimeout ->
                    client.post 'friendships/destroy', {user_id: item.id}, (err, data, response) ->
                      if err
                        console.log err
                        throw err
                      db.run 'UPDATE followings SET unfollowed_at=CURRENT_TIMESTAMP WHERE user_id=?', item.id, ->
                        console.log "#{item.screen_name} #{chalk.red('unfollow')}"
                  , (2000 * _i)
                _i++
          , (5000 * i)

        if i < parts
          unfollowLoop(i + 1)

      unfollowLoop(0)



program
  .version('1.0.0')
  .usage('-k hashtag -f 1000 -l tr')
  .option('-k, --keyword [value]', 'Izlenecek kelime')
  .option('-s, --search', 'Arama')
  .option('-f, --follow <n>', 'Takip edilecek kullanici limiti default: 100', Number)
  .option('-l, --lang [value]', 'Dil', String, 'tr')
  .option('-u, --unfollow', 'Takip etmeyenleri takibi birak', ->
    getUser (user) ->
      console.log("SORUNLU")
      unfollow(user)
  )
  .option('-c, --createdb', 'Veritabani olustur', ->
    db.run('CREATE TABLE IF NOT EXISTS
      followings(id INTEGER PRIMARY KEY AUTOINCREMENT, user_id VARCHAR(50) NOT NULL,
      screen_name VARCHAR(255) NULL, followed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      unfollowed_at DATETIME NULL)')
    console.log "#{chalk.green('db')} olusturuldu"
  )
  .parse(process.argv)

unless process.argv.slice(2).length
  program.outputHelp()
  process.exit(1)

unless program.unfollow? or program.createdb?
  unless (program.follow? or program.keyword?)
    program.outputHelp()
    process.exit(1)
  else
    if program.search?
      search(program.keyword)
    else
      listen_stream(program.keyword)
