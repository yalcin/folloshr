#! /usr/bin/env node
// Generated by CoffeeScript 1.9.1
(function() {
  var Twitter, _, add_follower, chalk, client, db, fs, getUser, listen_stream, program, sqlite3, unfollow;

  Twitter = require('twitter');

  sqlite3 = require('sqlite3').verbose();

  chalk = require('chalk');

  program = require('commander');

  fs = require('fs');

  db = new sqlite3.Database('folloshr.sqlite');

  _ = require('underscore');

  getUser = function(fn) {
    return client.get('account/settings', {}, (function(_this) {
      return function(err, user, response) {
        return fn(user);
      };
    })(this));
  };

  listen_stream = function(keyword) {
    var stream_count;
    stream_count = 0;
    return client.stream('statuses/filter', {
      track: keyword
    }, function(stream) {
      stream.on('data', function(tweet) {
        console.log((chalk.yellow(tweet.user.screen_name)) + " " + (chalk.cyan(tweet.text)));
        stream_count++;
        if (stream_count === program.follow) {
          process.exit(1);
        }
        if (tweet.lang === program.lang && tweet.user.id) {
          return add_follower(tweet);
        }
      });
      return stream.on('error', function(error) {
        throw error;
      });
    });
  };

  add_follower = function(tweet) {
    var query;
    query = 'SELECT user_id FROM followings WHERE user_id=\'' + tweet.user.id + '\'';
    return db.serialize(function() {
      return db.get(query, function(err, row) {
        if (err) {
          throw err;
        }
        if (typeof row === 'undefined') {
          return client.post('friendships/create', {
            user_id: tweet.user.id
          }, function(error, follow, response) {
            if (error) {
              throw error;
            }
            return db.run('INSERT INTO followings(user_id) VALUES(?)', tweet.user.id, function() {
              return console.log(tweet.user.screen_name + " " + (chalk.green('followed')));
            });
          });
        }
      });
    });
  };

  unfollow = function(user) {
    return db.serialize(function() {
      var countQuery;
      countQuery = 'SELECT COUNT(user_id) AS count FROM followings WHERE unfollowed_at IS NULL';
      return db.each(countQuery, function(err, row) {
        var count, i, j, max, parts, query, ref, results;
        count = row.count;
        max = 100;
        parts = count < max ? count / max : 1;
        console.log(parts);
        results = [];
        for (i = j = 0, ref = parts; 0 <= ref ? j <= ref : j >= ref; i = 0 <= ref ? ++j : --j) {
          query = "SELECT user_id FROM followings LIMIT " + (i * parts) + ", " + max + " ";
          results.push(db.map(query, function(err, map) {
            var user_ids;
            user_ids = _.map(map, function(val, key) {
              return val;
            });
            user_ids.join(',');
            return db.each(query, function(err, row) {
              if (err) {
                throw err;
              }
              return client.get('friendships/lookup', {
                user_id: user_ids
              }, function(err, item, response) {
                console.log(err);
                if (err) {
                  throw "lookup: " + err;
                }
                i = item[0];
                if (i.connections.indexOf('followed_by')) {
                  return console.log(i.screen_name + " seni " + (chalk.green('takip ediyor')));
                } else {
                  return client.post('friendships/destroy', {
                    user_id: row.user_id
                  }, function(err, item, response) {
                    throw err(err ? console.log(i.screen_name + " " + (chalk.red('unfollow'))) : void 0);
                  });
                }
              });
            });
          }));
        }
        return results;
      });
    });
  };

  client = new Twitter({
    consumer_key: 'JiZc1WV9cjsD1Zd3DD9OA',
    consumer_secret: 's2Gw1URCspqPn9w8iHnPIFLHGjnLTt4vVqMTtWVw',
    access_token_key: '10814712-70lRvXhHGFFh12uUkgOKJBIcCRhQ8RVxT3CTombQ',
    access_token_secret: 'huut20QUoHuGVNlGRu1SjYy2xDiapcvCXUKCzEOIcvQ'
  });

  program.version('1.0.0').usage('-k hashtag -f 1000 -l tr').option('-k, --keyword [value]', 'Izlenecek kelime').option('-f, --follow <n>', 'Takip edilecek kullanici limiti default: 100', Number).option('-l, --lang [value]', 'Dil', String, 'tr').option('-u, --unfollow', 'Takip etmeyenleri takibi birak', function() {
    return getUser(function(user) {
      return unfollow(user);
    });
  }).option('-c, --createdb', 'Veritabani olustur', function() {
    db.run('CREATE TABLE IF NOT EXISTS followings(id INTEGER PRIMARY KEY AUTOINCREMENT, user_id VARCHAR(50) NOT NULL, screen_name VARCHAR(255) NULL, followed_at DATETIME DEFAULT CURRENT_TIMESTAMP, unfollowed_at DATETIME NULL)');
    return console.log((chalk.green('db')) + " olusturuldu");
  }).parse(process.argv);

  if (!process.argv.slice(2).length) {
    program.outputHelp();
    process.exit(1);
  }

  if (!((program.unfollow != null) || (program.createdb != null))) {
    if (!((program.follow != null) || (program.keyword != null))) {
      program.outputHelp();
      process.exit(1);
    } else {
      listen_stream(program.keyword);
    }
  }

}).call(this);