#! /usr/bin/env coffee

config = require('./config')
Twitter = require('twitter')
sqlite3 = require('sqlite3').verbose()
chalk = require('chalk')
program = require('commander')
fs = require('fs')
db = new (sqlite3.Database)('folloshr.sqlite')
_ = require('underscore')

getUser = (fn) ->
  client.get 'account/settings', {}, (err, user, response) =>
    fn(user)

listen_stream = (keyword) ->
  stream_count = 0
  client.stream 'statuses/filter', { track: keyword }, (stream) ->
    stream.on 'data', (tweet) ->
      console.log "#{chalk.yellow(tweet.user.screen_name)} #{chalk.cyan(tweet.text)}"
      stream_count++
      if stream_count == program.follow
        process.exit 1
      if tweet.lang == program.lang and tweet.user.id
        add_follower tweet
    stream.on 'error', (error) ->
      throw error

add_follower = (tweet) ->
  query = 'SELECT user_id FROM followings WHERE user_id=\'' + tweet.user.id + '\''
  db.serialize ->
    db.get query, (err, row) ->
      throw err if err

      if typeof row == 'undefined'
        client.post 'friendships/create', { user_id: tweet.user.id }, (error, follow, response) ->
          throw error if error

          db.run 'INSERT INTO followings(user_id) VALUES(?)', tweet.user.id, ->
            console.log "#{tweet.user.screen_name} #{chalk.green('followed')}"

unfollow = (user) ->
  db.serialize ->
    countQuery = 'SELECT COUNT(user_id) AS count FROM followings WHERE unfollowed_at IS NULL'
    db.each countQuery, (err, row) ->
      count = row.count
      max = 100
      parts = if count < max
        count / max
      else
        1
      console.log parts
      for i in [0..parts]
        query = "SELECT user_id FROM followings LIMIT #{i * parts}, #{max} "
        db.map query, (err, map) ->
          user_ids = _.map map, (val, key) ->
            val
          user_ids.join(',')

          db.each query, (err, row) ->
            throw err if err
            client.get 'friendships/lookup', {user_id: user_ids}, (err, item, response) ->
              console.log err
              throw "lookup: #{err}" if err
              i = item[0]
              if i.connections.indexOf('followed_by')
                console.log "#{i.screen_name} seni #{chalk.green('takip ediyor')}"
              else
                client.post 'friendships/destroy', {user_id: row.user_id}, (err, item, response) ->
                  throw err if err
                  # db.run 'DELETE FROM followings WHERE user_id=?', row.user_id, ->
                    console.log "#{i.screen_name} #{chalk.red('unfollow')}"



client = new Twitter(
  consumer_key: config.consumer_key
  consumer_secret: config.consumer_secret
  access_token_key: config.access_token_key
  access_token_secret: config.access_token_secret)

program
  .version('1.0.0')
  .usage('-k hashtag -f 1000 -l tr')
  .option('-k, --keyword [value]', 'Izlenecek kelime')
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
    listen_stream(program.keyword)
