express = require('express')
app = express()
router = express.Router()
mongo = require('mongodb').MongoClient
objectId = require('mongodb').ObjectID
assert = require('assert')
jwt = require('jsonwebtoken')
config = require('../config')
app.set 'superSecret', config.secret
url = 'mongodb://localhost:27017/test'

### GET login page. ###

router.get '/login', (req, res) ->
  console.log 'test', req.userData
  res.render 'login',
    title: 'Login Page'
    loginsuccess: req.session.loginsuccess
    loginerror: req.session.loginerror
    loginerrors: req.session.loginerrors
  req.session.loginerror = null
  return

### GET create account page. ###

router.get '/createaccount', (req, res) ->
  res.render 'createaccount',
    title: 'Create Account Page'
    createaccountsuccess: req.session.createaccountsuccess
    createaccounterror: req.session.createaccounterror
    createaccounterrors: req.session.createaccounterrors
    firstname: req.session.firstname
    lastname: req.session.lastname
    email: req.session.email
  req.session.createaccounterrors = null
  req.session.createaccountsuccess = false
  req.session.createaccounterror = false
  return

### POST create account ###

router.post '/createaccount_submit', (req, res) ->
  req.session.firstname = req.body.firstname
  req.session.lastname = req.body.lastname
  req.session.email = req.body.email
  req.check('firstname', 'First name required').isLength min: 1
  req.check('lastname', 'Last name required').isLength min: 1
  req.check('email', 'Invalid email address').isEmail()
  req.check('password', 'Password is invalid').isLength min: 4
  req.check('confirmpassword', 'Passwords must match').equals req.body.password
  createaccounterrors = req.validationErrors()
  if createaccounterrors
    req.session.createaccounterrors = createaccounterrors
    req.session.createaccountsuccess = false
    req.session.createaccounterror = true
    res.redirect 'createaccount'
  else
    item = 
      firstname: req.body.firstname
      lastname: req.body.lastname
      email: req.body.email
      hash: req.body.password
    mongo.connect url, (err, db) ->
      assert.equal null, err
      db.collection('userdata').insertOne item, (err, result) ->
        assert.equal null, err
        req.session.createaccountsuccess = true
        req.session.createaccounterror = false
        req.session.firstname = req.body.firstname
        req.session.accountid = result.ops[0]._id
        res.redirect '/'
        db.close()
        return
      return
  return

### POST login ###

router.post '/login_submit', (req, res) ->
  req.check('email', 'Invalid email address').isEmail()
  req.check('password', 'Password is invalid').isLength min: 4
  loginerrors = req.validationErrors()
  if loginerrors
    req.session.loginerrors = loginerrors
    req.session.loginsuccess = false
    req.session.loginerror = true
    res.redirect '/login'
  else
    mongo.connect url, (err, db) ->
      assert.equal null, err
      db.collection('userdata').findOne { email: req.body.email }, (err, document) ->
        db.close()
        if document
          if document.hash == req.body.password
            token = jwt.sign(document, app.get('superSecret'), expiresIn: 1440)
            req.session.firstname = document.firstname
            req.session.lastname = document.lastname
            req.session.email = document.email
            req.session.accountid = document._id
            req.session.loginsuccess = true
            req.session.loginerror = false
            req.session.loginerrors = null
            req.session.token = token
            res.redirect '/'
          else
            req.session.loginsuccess = false
            req.session.loginerror = true
            req.session.loginerrors = [ {
              params: 'wrongpasswowrd'
              msg: 'Incorrect password provided'
            } ]
            res.redirect '/login'
        else
          req.session.loginsuccess = false
          req.session.loginerror = true
          req.session.loginerrors = [ {
            params: 'missingaccount'
            msg: 'Account not found. Please check your email address and try again'
          } ]
          res.redirect '/login'
        return
      return
  return

### GET home page after delete. ###

router.get '/accountdeleted', (req, res) ->
  createaccountsuccess = false
  editaccountsuccess = false
  deleteaccountsuccess = true
  res.render 'index',
    title: 'Home Page'
    createaccountsuccess: createaccountsuccess
    editaccountsuccess: editaccountsuccess
    deleteaccountsuccess: deleteaccountsuccess
    firstname: req.session.firstname
  req.session.createaccountsuccess = null
  req.session.editaccountsuccess = null
  req.session.deleteaccountsuccess = null
  return

### Authentication Middleware ###

router.use (req, res, next) ->
  token = req.body.token or req.query.token or req.headers['x-access-token'] or req.session.token
  if token
    jwt.verify token, app.get('superSecret'), (err, decoded) ->
      if err
        return res.json(
          success: false
          message: 'Failed to authenticate token.')
      else
        req.decoded = decoded
        next()
      return
  else
    next()
  return

### GET home page. ###

router.get '/', (req, res) ->
  createaccountsuccess = false
  console.log 'decoded', req.decoded
  if req.session.createaccountsuccess
    createaccountsuccess = req.session.createaccountsuccess
  editaccountsuccess = false
  if req.session.editaccountsuccess
    editaccountsuccess = req.session.editaccountsuccess
  changepasswordsuccess = false
  if req.session.changepasswordsuccess
    changepasswordsuccess = req.session.changepasswordsuccess
  res.render 'index',
    title: 'Home Page'
    createaccountsuccess: createaccountsuccess
    editaccountsuccess: editaccountsuccess
    changepasswordsuccess: changepasswordsuccess
    firstname: req.session.firstname
  req.session.createaccountsuccess = null
  req.session.editaccountsuccess = null
  req.session.changepasswordsuccess = null
  return

### GET logout ###

router.get '/logout', (req, res, next) ->
  req.decoded = null
  req.session.destroy()
  res.redirect '/'
  return

### GET edit acocunt page ###

router.get '/editaccount', (req, res) ->
  if req.session.token
    res.render 'editaccount',
      title: 'Edit Account Page'
      editaccountsuccess: req.session.editaccountsuccess
      editaccounterror: req.session.editaccounterror
      editaccounterrors: req.session.editaccounterrors
      firstname: req.session.firstname
      lastname: req.session.lastname
      email: req.session.email
    req.session.editaccounterrors = null
    req.session.editaccountsuccess = false
    req.session.editaccounterror = false
  else
    res.redirect '/'
  return

### POST edit account ###

router.post '/editaccount_submit', (req, res) ->
  if req.session.token
    editaccounterrors = undefined
    if req.session.firstname == req.body.firstname and req.session.lastname == req.body.lastname and req.session.email == req.body.email
      editaccounterrors = [ {
        param: 'nochange'
        msg: 'No edits made to current value. Changes required before submit'
      } ]
    else
      req.check('firstname', 'First name required').isLength min: 1
      req.check('lastname', 'Last name required').isLength min: 1
      req.check('email', 'Invalid email address').isEmail()
      editaccounterrors = req.validationErrors()
    if editaccounterrors
      req.session.editaccounterrors = editaccounterrors
      req.session.editaccountsuccess = false
      req.session.editaccounterror = true
      res.redirect 'editaccount'
    else
      item = 
        firstname: req.body.firstname
        lastname: req.body.lastname
        email: req.body.email
      mongo.connect url, (err, db) ->
        assert.equal null, err
        db.collection('userdata').updateOne { '_id': objectId(req.session.accountid) }, { $set: item }, (err, result) ->
          assert.equal null, err
          db.close()
          req.session.firstname = req.body.firstname
          req.session.lastname = req.body.lastname
          req.session.email = req.body.email
          req.session.editaccountsuccess = true
          req.session.editaccounterror = false
          req.session.firstname = req.body.firstname
          res.redirect '/'
          return
        return
  else
    res.redirect '/'
  return

### GET chagne password page ###

router.get '/changepassword', (req, res) ->
  if req.session.token
    res.render 'changepassword',
      title: 'Change Password Page'
      changepasswordsuccess: req.session.changepasswordsuccess
      changepassworderror: req.session.changepassworderror
      changepassworderrors: req.session.changepassworderrors
      firstname: req.session.firstname
    req.session.changepassworderrors = null
    req.session.changepasswordsuccess = false
    req.session.changepassworderror = false
  else
    res.redirect '/'
  return

### POST change password ###

router.post '/changepassword_submit', (req, res) ->
  if req.session.token
    req.check('password', 'Password is invalid').isLength min: 4
    req.check('confirmpassword', 'Passwords must match').equals req.body.password
    errors = req.validationErrors()
    if errors
      req.session.changepassworderrors = errors
      req.session.changepasswordsuccess = false
      req.session.changepassworderror = true
      res.redirect 'changepassword'
    else
      item = hash: req.body.password
      mongo.connect url, (err, db) ->
        assert.equal null, err
        db.collection('userdata').updateOne { '_id': objectId(req.session.accountid) }, { $set: item }, (err, result) ->
          assert.equal null, err
          db.close()
          req.session.changepasswordsuccess = true
          req.session.changepassworderror = false
          res.redirect '/'
          return
        return
  else
    res.redirect '/'
  return

### GET delete acocunt page ###

router.get '/deleteaccount', (req, res) ->
  if req.session.token
    res.render 'deleteaccount',
      title: 'Delete Account Page'
      firstname: req.session.firstname
      lastname: req.session.lastname
      email: req.session.email
    req.session.deleteaccounterrors = null
    req.session.deleteaccountsuccess = false
    req.session.deleteaccounterror = false
  else
    res.redirect '/'
  return

### POST delete account ###

router.post '/deleteaccount_submit', (req, res) ->
  if req.session.token
    mongo.connect url, (err, db) ->
      assert.equal null, err
      db.collection('userdata').deleteOne { '_id': objectId(req.session.accountid) }, (err, result) ->
        if result.deletedCount
          assert.equal null, err
          db.close()
          req.session.destroy()
          res.redirect 'accountdeleted'
        else
          req.session.error = 'Zero records deleted'
          req.session.message = 'Unable to find account'
          res.redirect 'error'
        return
      return
  else
    res.redirect '/'
  return
module.exports = router