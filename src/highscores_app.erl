-module(highscores_app).
-behaviour(application).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-export([start/2, stop/1]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

start(_StartType, _StartArgs) ->
    {ok, Host} = application:get_env(highscores, bind_host),
    {ok, Port} = application:get_env(highscores, bind_port),
    {ok, Pool} = application:get_env(highscores, acceptors),
    Dispatch = cowboy_router:compile([
        {'_', [{"/highscores/:userid/:level", [{level, int}], highscores_rest, []}]}
    ]),
    cowboy:start_http(
        highscores, Pool,
        [{ip, Host},{port, Port}],
        [{env, [{dispatch, Dispatch}]}]
    ),
    highscores_sup:start_link().

stop(_State) ->
    ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
