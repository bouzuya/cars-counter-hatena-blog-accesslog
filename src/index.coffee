{ Promise } = require 'es6-promise'
cheerio = require 'cheerio'
fetch = require 'node-fetch'
FormData = require 'form-data'

class Client
  constructor: ({ username, password, domain }) ->
    @_username = username
    @_password = password
    @_domain = domain
    @_cookies = null

  fetch: ->
    @_headers()
      .then (headers) =>
        url = "http://blog.hatena.ne.jp/#{@_username}/#{@_domain}/accesslog"
        fetch url, { headers }
      .then (res) ->
        res.text()
      .then (html) ->
        $ = cheerio.load html
        $counts = $ '#admin-main tr.count td'
        today = parseInt $counts.eq(0).text(), 10
        weekly = parseInt $counts.eq(1).text(), 10
        monthly = parseInt $counts.eq(2).text(), 10
        total = parseInt $counts.eq(3).text(), 10
        { today, weekly, monthly, total }

  _login: ->
    username = @_username
    password = @_password
    url = 'https://www.hatena.ne.jp/login'
    form = new FormData()
    form.append 'name', username
    form.append 'password', password
    fetch url, method: 'POST', body: form
      .then (res) ->
        res.headers.getAll 'set-cookie'
      .then (cookies) ->
        parsed = {}
        cookies.forEach (cookie) ->
          pattern = new RegExp('\\s*;\\s*')
          cookie.split(pattern).forEach (i) ->
            [encodedKey, encodedValue] = i.split('=')
            key = decodeURIComponent(encodedKey)
            value = decodeURIComponent(encodedValue)
            parsed[key] = value
          , {}
        parsed
      .then (parsed) =>
        @_cookies = parsed

  _headers: ->
    promise = if @_cookies? then Promise.resolve() else @_login()
    promise
      .then =>
        cookie: 'b=' + @_cookies['b'] + ';rk=' + @_cookies['rk']

module.exports = (callback) ->
  try
    username = process.env.HATENA_USERNAME
    password = process.env.HATENA_PASSWORD
    domain = process.env.HATENA_BLOG_DOMAIN

    return callback(new Error('HATENA_USERNAME is blank')) unless username?
    return callback(new Error('HATENA_PASSWORD is blank')) unless password?
    return callback(new Error('HATENA_BLOG_DOMAIN is blank')) unless domain?

    client = new Client { username, password, domain }
    client.fetch()
      .then ({ today, weekly, monthly, total }) ->
        counts =
          'hatena-blog-today': today
          'hatena-blog-weekly': weekly
          'hatena-blog-monthly': monthly
          'hatena-blog-total': total
        callback null, counts
      .catch (error) ->
        callback error
  catch error
    callback error
