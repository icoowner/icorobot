tdcli = dofile('./tg/tdcli.lua')

serpent = (loadfile "./libs/serpent.lua")()

feedparser = (loadfile "./libs/feedparser.lua")()

our_id = 123456789 -- Put Here Your Bot ID

URL = require "socket.url"

http = require "socket.http"

https = require "ssl.https"

ltn12 = require "ltn12"


json = (loadfile "./libs/JSON.lua")()

mimetype = (loadfile "./libs/mimetype.lua")()

redis = (loadfile "./libs/redis.lua")()

JSON = (loadfile "./libs/dkjson.lua")()

local lgi = require ('lgi')


local notify = lgi.require('Notify')


notify.init ("Telegram updates")



chats = {}



function do_notify (user, msg)

  local n = notify.Notification.new(user, msg)

  n:show ()

end


function dl_cb (arg, data)

end


function serialize_to_file(data, file, uglify)

  file = io.open(file, 'w+')

  local serialized

  if not uglify then

    serialized = serpent.block(data, {

        comment = false,

        name = '_'

      })

  else

    serialized = serpent.dump(data)

  end

  file:write(serialized)

  file:close()

end


function load_data(filename)

	local f = io.open(filename)

	if not f then

		return {}

	end

	local s = f:read('*all')

	f:close()

	local data = JSON.decode(s)

	return data

end


function save_data(filename, data)

	local s = JSON.encode(data)

	local f = io.open(filename, 'w')

	f:write(s)

	f:close()

end


function match_plugins(msg)

  for name, plugin in pairs(plugins) do

    match_plugin(plugin, name, msg)

  end

end


function save_config( )

  serialize_to_file(_config, './data/config.lua')

  print ('saved config into ./data/config.lua')

end


function create_config( )

  -- A simple config with basic plugins and ourselves as privileged user

  config = {

    enabled_plugins = {

    "banhammer",

	"banhammer-fa",

    "groupmanager",

	"groupmanager-fa",

    "msg-checks",

    "plugins",

    "tools",

    "expiretime",

    "mute-time",

    "del",

	"lock-fosh"


 },

    sudo_users = {123456789},

    admins = {},

    disabled_channels = {},

    moderation = {data = './data/moderation.json'},

    info_text = [[👾ɨċօ tɛaʍ👾
〰〰〰〰〰〰〰〰〰〰〰〰
👤ADMIN 1 : @mrqro

👥ADMIN 2 : @sudoico

👻ROBOT : @sudo_ico_bot

🌐CHANNEL : @icoteam
〰〰〰〰〰〰〰〰〰〰〰〰]],

  }

  serialize_to_file(config, './data/config.lua')

  print ('saved config into conf.lua')

end


-- Returns the config from config.lua file.

-- If file doesn't exist, create it.

function load_config( )

  local f = io.open('./data/config.lua', "r")

  -- If config.lua doesn't exist

  if not f then

    print ("Created new config file: ./data/config.lua")

    create_config()

  else

    f:close()

  end

  local config = loadfile ("./data/config.lua")()

  for v,user in pairs(config.sudo_users) do

    print("Allowed user: " .. user)

  end

  return config

end

plugins = {}

_config = load_config()


function load_plugins()

  local config = loadfile ("./data/config.lua")()

      for k, v in pairs(config.enabled_plugins) do

        

        print("Loading Plugins", v)


        local ok, err = pcall(function()

          local t = loadfile("plugins/"..v..'.lua')()

          plugins[v] = t

        end)


        if not ok then

          print('\27[31mError loading plugins '..v..'\27[39m')

        print(tostring(io.popen("lua plugins/"..v..".lua"):read('*all')))

            print('\27[31m'..err..'\27[39m')

        end

    end

end


function scandir(directory)

  local i, t, popen = 0, {}, io.popen

  for filename in popen('ls -a "'..directory..'"'):lines() do

    i = i + 1

    t[i] = filename

  end

  return t

end


function plugins_names( )

  local files = {}

  for k, v in pairs(scandir("plugins")) do

    -- Ends with .lua

    if (v:match(".lua$")) then

      table.insert(files, v)

    end

  end

  return files

end


-- Function name explains what it does.

function file_exists(name)

  local f = io.open(name,"r")

  if f ~= nil then

    io.close(f)

    return true

  else

    return false

  end

end


function gp_type(chat_id)

  local gp_type = "pv"

  local id = tostring(chat_id)

    if id:match("^-100") then

      gp_type = "channel"

    elseif id:match("-") then

      gp_type = "chat"

  end

  return gp_type

end


function is_reply(msg)

  local var = false

    if msg.reply_to_message_id_ ~= 0 then -- reply message id is not 0

      var = true

    end

  return var

end


function is_supergroup(msg)

  chat_id = tostring(msg.chat_id_)

  if chat_id:match('^-100') then --supergroups and channels start with -100

    if not msg.is_post_ then

    return true

    end

  else

    return false

  end

end


function is_channel(msg)

  chat_id = tostring(msg.chat_id_)

  if chat_id:match('^-100') then -- Start with -100 (like channels and supergroups)

  if msg.is_post_ then -- message is a channel post

    return true

  else

    return false

  end

  end

end


function is_group(msg)

  chat_id = tostring(msg.chat_id_)

  if chat_id:match('^-100') then --not start with -100 (normal groups does not have -100 in first)

    return false

  elseif chat_id:match('^-') then

    return true

  else

    return false

  end

end


function is_private(msg)

  chat_id = tostring(msg.chat_id_)

  if chat_id:match('^-') then --private chat does not start with -

    return false

  else

    return true

  end

end


function check_markdown(text) --markdown escape ( when you need to escape markdown , use it like : check_markdown('your text')

		str = text

		if str:match('_') then

			output = str:gsub('_','\\_')

		elseif str:match('*') then

			output = str:gsub('*','\\*')

		elseif str:match('`') then

			output = str:gsub('`','\\`')

		else

			output = str

		end

	return output

end


function is_sudo(msg)

  local var = false

  -- Check users id in config

  for v,user in pairs(_config.sudo_users) do

    if user == msg.sender_user_id_ then

      var = true

    end

  end

  return var

end


function is_owner(msg)

  local var = false

  local data = load_data(_config.moderation.data)

  local user = msg.sender_user_id_

  if data[tostring(msg.chat_id_)] then

    if data[tostring(msg.chat_id_)]['owners'] then

      if data[tostring(msg.chat_id_)]['owners'][tostring(user)] then

        var = true

      end

    end

  end


  for v,user in pairs(_config.admins) do

    if user[1] == msg.sender_user_id_ then

      var = true

  end

end


  for v,user in pairs(_config.sudo_users) do

    if user == msg.sender_user_id_ then

        var = true

    end

  end

  return var

end


function is_admin(msg)

  local var = false

  local user = msg.sender_user_id_

  for v,user in pairs(_config.admins) do

    if user[1] == msg.sender_user_id_ then

      var = true

  end

end


  for v,user in pairs(_config.sudo_users) do

    if user == msg.sender_user_id_ then

        var = true

    end

  end

  return var

end


--Check if user is the mod of that group or not

function is_mod(msg)

  local var = false

  local data = load_data(_config.moderation.data)

  local usert = msg.sender_user_id_

  if data[tostring(msg.chat_id_)] then

    if data[tostring(msg.chat_id_)]['mods'] then

      if data[tostring(msg.chat_id_)]['mods'][tostring(usert)] then

        var = true

      end

    end

  end


  if data[tostring(msg.chat_id_)] then

    if data[tostring(msg.chat_id_)]['owners'] then

      if data[tostring(msg.chat_id_)]['owners'][tostring(usert)] then

        var = true

      end

    end

  end


  for v,user in pairs(_config.admins) do

    if user[1] == msg.sender_user_id_ then

      var = true

  end

end


  for v,user in pairs(_config.sudo_users) do

    if user == msg.sender_user_id_ then

        var = true

    end

  end

  return var

end


function is_owner1(chat_id, user_id)

  local var = false

  local data = load_data(_config.moderation.data)

  local user = user_id

  if data[tostring(chat_id)] then

    if data[tostring(chat_id)]['owners'] then

      if data[tostring(chat_id)]['owners'][tostring(user)] then

        var = true

      end

    end

  end


  for v,user in pairs(_config.admins) do

    if user[1] == user_id then

      var = true

  end

end


  for v,user in pairs(_config.sudo_users) do

    if user == user_id then

        var = true

    end

  end

  return var

end


function is_admin1(user_id)

  local var = false

  local user = user_id

  for v,user in pairs(_config.admins) do

    if user[1] == user_id then

      var = true

  end

end


  for v,user in pairs(_config.sudo_users) do

    if user == user_id then

        var = true

    end

  end

  return var

end


