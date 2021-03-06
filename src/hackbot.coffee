# Description:
#   Self service team and user administration scripts.
#
# Configuration:
#   HACKBOT_PASSWORD: required
#   HACK24API_URL: required
#
# Commands:
#   hubot can you see the api? - checks if the API is visible
#   hubot what are your prime directives? - cites hubot's prime directives
#   hubot my id - echos the ID hubot knows you as
#   hubot create team <team name> - tries to create team with name <team name> and adds you to it
#   hubot leave my team - removes you from your current team
#   hubot find teams like <query> - displays up to three teams matching the specified query
#   hubot tell me about team <team name> - displays information about the specific team
#   hubot add @<username> to my team - adds @<username> to your team
#   hubot tell me about my team - displays information about your team
#
# Author:
#   David Wood <david.p.wood@gmail.com>
#

{Client} = require '../lib/client'
slug = require 'slug'

slugify = (name) -> slug(name, { lower: true })

module.exports = (robot) ->

  robot.hack24client = new Client robot


  robot.respond /can you see the api\??/i, (response) =>
    response.reply "I'll have a quick look for you..."
    robot.hack24client.checkApi()
      .then (res) ->
        if res.ok
          response.reply 'I see her!'
        else
          response.reply "I'm sorry, there appears to be a problem; something about \"#{res.statusCode}\""
      .catch (err) ->
        console.error "API check failed: #{err.message}"
        response.reply 'I\'m sorry, there appears to be a big problem!'

  robot.respond /what are your prime directives\??/i, (response) ->
    response.reply "1. Serve the public trust\n2. Protect the innocent hackers\n3. Uphold the Code of Conduct\n4. [Classified]"


  robot.respond /my id/i, (response) ->
    response.reply "Your id is #{response.message.user.id}"


  robot.respond /create team (.*)/i, (response) ->
    userId = response.message.user.id
    userName = response.message.user.name
    teamName = response.match[1]

    robot.hack24client.getUser(userId)
      .then (res) ->

        email_address = robot.brain.data.users[userId].email_address

        if res.statusCode is 404
          return robot.hack24client.createUser(userId, userName, email_address)
            .then (res) ->
              if res.ok
                return robot.hack24client.createTeam(teamName, userId, email_address)
                  .then (res) ->
                    if res.ok
                      return response.reply "Welcome to team #{teamName}!"

                    if res.statusCode is 409
                      return response.reply 'Sorry, but that team already exists!'

                    response.reply 'Sorry, I can\'t create your team :frowning:'

              if res.statusCode is 403
                return response.reply 'Sorry, you don\'t have permission to create a team.'

              response.reply 'Sorry, I can\'t create your user account :frowning:'

        if res.user.team.id isnt undefined
          response.reply "You're already a member of #{res.user.team.name}!"
          return

        robot.hack24client.createTeam(teamName, userId, email_address)
          .then (res) ->
            if res.ok
              return response.reply "Welcome to team #{teamName}!"

            if res.statusCode is 403
              return response.reply 'Sorry, you don\'t have permission to create a team.'

            if res.statusCode is 409
              return response.reply 'Sorry, but that team already exists!'

            response.reply 'Sorry, I can\'t create your team :frowning:'

    .catch (err) ->
        response.reply 'I\'m sorry, there appears to be a big problem!'


  robot.respond /tell me about team (.*)/i, (response) ->
    teamId = slugify(response.match[1])

    robot.hack24client.getTeam(teamId)
      .then (res) ->
        if res.statusCode is 404 then return response.reply "Sorry, I can't find that team."
        if !res.ok then return response.reply 'Sorry, there was a problem when I tried to look up that team :frowning:'

        if res.team.members.length == 0
          return response.reply "\"#{res.team.name}\" is an empty team."

        if res.team.members.length == 1 and res.team.members[0].id == response.message.user.id
          motto = if res.team.motto is null then "and you have not yet set your motto!" else "and your motto is: #{res.team.motto}"
          return response.reply "You are the only member of \"#{res.team.name}\" #{motto}"

        memberList = res.team.members.map((member) => member.name)
        noun = if res.team.members.length == 1 then 'member' else 'members'
        motto = if res.team.motto is null then "They don't yet have a motto!" else "They say: #{res.team.motto}"

        response.reply "\"#{res.team.name}\" has #{res.team.members.length} #{noun}: #{memberList.join(', ')}\r\n#{motto}"
      .catch (err) ->
        console.log("ERROR: " + err)
        response.reply 'I\'m sorry, there appears to be a big problem!'


  robot.respond /leave my team/i, (response) ->
    userId = response.message.user.id

    robot.hack24client.getUser(userId)
      .then (res) ->
        if !res.ok or res.user.team.id is undefined
          return response.reply 'You\'re not in a team! :goberserk:'

        email_address = robot.brain.data.users[userId].email_address

        return robot.hack24client.removeTeamMember(res.user.team.id, userId, email_address)
          .then (_res) ->
            if _res.ok
              return response.reply "OK, you've been removed from team \"#{res.user.team.name}\""

            if _res.statusCode is 403
              return response.reply "Sorry, you don't have permission to leave your team."

            response.reply "Sorry, I tried, but something went wrong."

      .catch (err) ->
        response.reply 'I\'m sorry, there appears to be a big problem!'


  robot.respond /find teams like (.*)/i, (response) ->
    nameFilter = response.match[1]

    robot.hack24client.findTeams(nameFilter)
      .then (res) ->
        if res.teams.length == 0
          return response.reply 'None found.'

        names = res.teams[..2].map((team) -> team.name)
        response.reply "Found #{res.teams.length} teams; here's a few: #{names.join(', ')}"

      .catch (err) ->
        response.reply 'I\'m sorry, there appears to be a big problem!'


  robot.respond /our motto is (.*)/i, (response) ->
    userId = response.message.user.id
    userName = response.message.user.name
    motto = response.match[1]

    robot.hack24client.getUser(userId)
      .then (res) ->

        if (!res.ok and res.statusCode is 404) or res.user.team.id is undefined
          return response.reply "You're not in a team! :goberserk:"

        email_address = robot.brain.data.users[userId].email_address

        robot.hack24client.updateMotto(motto, res.user.team.id, email_address)
          .then (updateMottoResponse) ->
            if updateMottoResponse.ok
              return response.reply "So it is! As #{res.user.team.name} say: #{motto}"

            if updateMottoResponse.statusCode is 403
              return response.reply 'Sorry, only team members can change the motto.'

            response.reply "Sorry, I tried, but something went wrong."

      .catch (err) ->
        console.log("ERROR: " + err)
        response.reply 'I\'m sorry, there appears to be a big problem!'


  robot.respond /add @([a-z0-9.-_]+)\s+to my team/, (response) ->
    otherUsername = response.match[1]
    userId = response.message.user.id

    robot.hack24client.getUser(userId)
      .then (res) ->
        if res.user.team.id is undefined
          return response.reply "I would, but you're not in a team..."

        teamId = res.user.team.id

        otherUser = {}
        for _, user of robot.brain.data.users
          if user.name == otherUsername
            otherUser = user
            break

        addUserToTeam = (teamId, otherUserId, emailAddress) =>
          robot.hack24client.addUserToTeam(teamId, otherUserId, emailAddress)
            .then (res) ->
              if res.statusCode is 400
                return response.reply "Sorry, #{otherUsername} is already in another team and must leave that team first."

              if res.statusCode is 403
                return response.reply "Sorry, you don't have permission to add people to your team."

              response.reply 'Done!'

        emailAddress = robot.brain.data.users[userId].email_address

        return robot.hack24client.getUser(otherUser.id)
          .then (res) =>
            if res.ok
              return addUserToTeam teamId, otherUser.id, emailAddress

            if res.statusCode is 404
              robot.hack24client.createUser(otherUser.id, otherUser.name, emailAddress)
                .then (res) ->
                  return addUserToTeam teamId, otherUser.id, emailAddress


  robot.respond /tell me about my team/i, (response) ->
    userId = response.message.user.id

    robot.hack24client.getUser(userId)
      .then (res) ->
        if (!res.ok and res.statusCode is 404) or res.user.team.id is undefined
          return response.reply "You're not in a team! :goberserk:"

        memberList = res.user.team.members.map((member) => member.name)
        noun = if res.user.team.members.length == 1 then 'member' else 'members'
        motto = if res.user.team.motto is null then "They don't yet have a motto!" else "They say: #{res.user.team.motto}"

        response.reply "\"#{res.user.team.name}\" has #{res.user.team.members.length} #{noun}: #{memberList.join(', ')}\r\n#{motto}"
      .catch (err) ->
        console.log("ERROR: " + err)
        response.reply 'I\'m sorry, there appears to be a big problem!'
