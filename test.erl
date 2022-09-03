-module(test).
-export([start/0,tear/0]).
-import(server, [storeUserDB/3,storeMessageDB/4, findUserName/1, listOfActiveUsers/0, findPid/1, getUserMsgs/1, retrive_top_N_msgs/4]).
-include_lib("eunit/include/eunit.hrl").
-record(userList, {clientPid, name, status}).
-record(messageList, {from, to, message, sentTime}).

start() ->
  mnesia:create_schema([node()]),
  mnesia:start(),
  try
    mnesia:table_info(start, userList)
  catch
    exit: _->
      mnesia:create_table(userList, [{attributes, record_info(fields, userList)}, {type, bag}, {disc_copies, [node()]}])
  end,

  try
    mnesia:table_info(start, messageList)
  catch
    exit: _->
      mnesia:create_table(messageList, [{attributes, record_info(fields, messageList)}, {type, bag}, {disc_copies, [node()]}])
  end,
  server:storeUserDB(1, "q", "Active"),
  server:storeUserDB(2, "w", "Inactive"),
  server:storeUserDB(3, "e", "Active"),
  server:storeUserDB(4, "r", "Active"),
  server:storeUserDB(5, "t", "Active"),
  server:storeUserDB(6, "y", "Active"),
  server:storeUserDB(7, "u", "Active"),
  server:storeUserDB(8, "i", "Active"),
  server:storeUserDB(8, "o", "Active"),
  server:storeUserDB(10, "p", "Inactive"),
  server:storeMessageDB("q", "w", "Hello", 1),
  server:storeMessageDB("w", "Everyone", "Hi", 2),
  server:storeMessageDB("y", "Everyone", "hey", 3),
  server:storeMessageDB("t", "w", "cool", 4),
  server:storeMessageDB("t", "i", "demn", 5),
  server:storeMessageDB("r", "o", "what?", 6),
  server:storeMessageDB("e", "q", "vvv", 7),
  server:storeMessageDB("u", "Everyone", "no", 8),
  server:storeMessageDB("p", "y", "yes", 9),
  server:storeMessageDB("w", "h", "haha", 10).

server_test() ->
  ?assertEqual({userList,1,"q","Active"}, server:findUserName("q")),
  ?assertEqual([], server:findUserName("k")),
  ?assertEqual({userList, 3, "e", "Active"}, server:findPid(3)),
  %?assertEqual({userList, 8, "i", "Active"}, server:findPid(8)),
  ?assertEqual([{messageList,"y","Everyone","hey",3},
                {messageList,"w","Everyone","Hi",2},
                {messageList,"u","Everyone","no",8}], server:getUserMsgs("e")),
  ?assertEqual([{messageList,"y","Everyone","hey",3},
                {messageList,"w","Everyone","Hi",2},
                {messageList,"u","Everyone","no",8}], server:getUserMsgs("l")),
  ?assertEqual([{messageList,"y","Everyone","hey",3},
                {messageList,"w","Everyone","Hi",2},
                {messageList,"u","Everyone","no",8}], server:getUserMsgs(kk)),
  ?assertEqual([{messageList, "u", "Everyone", "no", 8}, {messageList, "y", "Everyone", "hey", 3}, {messageList, "w", "Everyone", "Hi", 2}], server:retrive_top_N_msgs("q", [{messageList, "w", "Everyone", "Hi", 2}, {messageList, "y", "Everyone", "hey", 3}, {messageList, "u", "Everyone", "no", 8}], [], 4)),
  ?assertEqual([], server:retrive_top_N_msgs("l", [], [], 4)),
  ?assertEqual([{messageList, "w", "Everyone", "Hi", 2}, {messageList, "y", "Everyone", "hey", 3}], server:retrive_top_N_msgs("q", [{messageList, "y", "Everyone", "hey", 3}, {messageList, "w", "Everyone", "Hi", 2}, {messageList, "u", "Everyone", "no", 8}], [], 2)).

tear() ->
  mnesia:delete_table(userList),
  mnesia:delete_table(messageList),
  mnesia:delete_schema([node()]).

