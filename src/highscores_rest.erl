-module(highscores_rest).
-compile(export_all).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

init(_Transport, _Req, []) ->
    {upgrade, protocol, cowboy_rest}.

allowed_methods(Req, State) ->
    {[<<"GET">>, <<"POST">>, <<"DELETE">>], Req, State}.

content_types_provided(Req, State) ->
    {[{{<<"text">>, <<"plain">>, []}, to_text}], Req, State}.

content_types_accepted(Req, State) ->
    {[{{<<"text">>, <<"plain">>, []}, from_text}], Req, State}.

resource_exists(Req, undefined) ->
    {Level, Req1} = cowboy_req:binding(level, Req),
    {UserID, Req2} = cowboy_req:binding(userid, Req1),
    lager:debug("Getting highscores for ~p/~p...", [UserID, Level]),
    case get_highscores(UserID, Level) of
        undefined -> {false, Req2, undefined};
        Score     -> {true, Req2, Score}
    end.

to_text(Req, Score) ->
    {integer_to_list(Score), Req, Score}.

from_text(Req, OldScore) ->
    {Level, Req1} = cowboy_req:binding(level, Req),
    {UserID, Req2} = cowboy_req:binding(userid, Req1),
    {ok, Body, Req3} = cowboy_req:body(Req2),
    try list_to_integer(binary_to_list(Body)) of
        NewScore ->
            lager:debug("Setting highscores for ~p/~p (~p to ~p)...", [UserID, Level, OldScore, NewScore]),
            ok = set_highscores(UserID, Level, NewScore),
            {true, Req3, NewScore}
    catch
        error:badarg ->
            {false, Req3, OldScore}
    end.

delete_resource(Req, OldScore) ->
    {Level, Req1} = cowboy_req:binding(level, Req),
    {UserID, Req2} = cowboy_req:binding(userid, Req1),
    lager:debug("Deleting highscores for ~p/~p (~p)...", [UserID, Level, OldScore]),
    ok = del_highscores(UserID, Level),
    {true, Req2, OldScore}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

set_highscores(UserID, Level, Scores) when is_integer(Level), is_integer(Scores) ->
    {Host, Port} = get_riak_endpoint(),
    Template = "http://~s:~B/riak/highscores/~s-~B",
    URL = lists:flatten(io_lib:format(Template, [Host, Port, UserID, Level])),
    case httpc:request(put, {URL, [], "text/plain", integer_to_list(Scores)}, [], []) of
        {ok, {{_, 204, _}, _, _}} -> ok
    end.

get_highscores(UserID, Level) when is_integer(Level) ->
    {Host, Port} = get_riak_endpoint(),
    Template = "http://~s:~B/riak/highscores/~s-~B",
    URL = lists:flatten(io_lib:format(Template, [Host, Port, UserID, Level])),
    case httpc:request(get, {URL, []}, [], []) of
        {ok, {{_, 404, _}, _, _}} -> undefined;
        {ok, {{_, 200, _}, _, Data}} -> list_to_integer(Data)
    end.

del_highscores(UserID, Level) when is_integer(Level) ->
    {Host, Port} = get_riak_endpoint(),
    Template = "http://~s:~B/riak/highscores/~s-~B",
    URL = lists:flatten(io_lib:format(Template, [Host, Port, UserID, Level])),
    case httpc:request(delete, {URL, []}, [], []) of
        {ok, {{_, 204, _}, _, _}} -> ok
    end.

get_riak_endpoint() ->
    case application:get_env(highscores, riak_nodes) of
        undefined -> exit(no_riak_nodes);
        {ok, []} -> exit(no_riak_nodes);
        {ok, Nodes} -> lists:nth(random:uniform(length(Nodes)), Nodes)
    end.
