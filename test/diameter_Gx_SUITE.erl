%% Copyright 2017,2018, Travelping GmbH <info@travelping.com>
%%
%% This program is free software: you can redistribute it and/or modify
%% it under the terms of the GNU Lesser General Public License as
%% published by the Free Software Foundation, either version 3 of the
%% License, or (at your option) any later version.
%%
%% This program is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
%% GNU Lesser General Public License for more details.
%%
%% You should have received a copy of the GNU Lesser General Public License
%% along with this program. If not, see <http://www.gnu.org/licenses/>.

-module(diameter_Gx_SUITE).

-compile([nowarn_export_all, export_all]).

-include_lib("common_test/include/ct.hrl").
-include_lib("diameter/include/diameter_gen_base_rfc6733.hrl").
-include("../include/diameter_3gpp_ts29_212.hrl").
-include("../include/ergw_aaa_session.hrl").
-include("ergw_aaa_test_lib.hrl").

-import(ergw_aaa_test_lib, [meck_init/1, meck_reset/1, meck_unload/1, meck_validate/1,
			    get_stats/1, diff_stats/2, wait_for_diameter/2]).

-define(HUT, ergw_aaa_gx).
-define(SERVICE, ergw_aaa_gx).

-define(STATIC_CONFIG,
	[{'NAS-Identifier',        <<"NAS">>},
	 {'Framed-Protocol',       'PPP'},
	 {'Service-Type',          'Framed-User'}]).

-define(DIAMETER_TRANSPORT,
	[
	 {connect_to, <<"aaa://127.0.0.1">>}
	]).
-define(DIAMETER_FUNCTION,
	{?SERVICE,
	 [{handler, ergw_aaa_diameter},
	  {'Origin-Host', <<"127.0.0.1">>},
	  {'Origin-Realm', <<"example.com">>},
	  {transports, [?DIAMETER_TRANSPORT]}
	 ]}).
-define(DIAMETER_CONFIG,
	[{function, ?SERVICE},
	 {'Destination-Realm', <<"test-srv.example.com">>}]).

-define(CONFIG,
	[{functions, [?DIAMETER_FUNCTION]},
	 {handlers,
	  [{ergw_aaa_static, ?STATIC_CONFIG},
	   {ergw_aaa_gx, ?DIAMETER_CONFIG}
	  ]},
	 {services,
	  [{'Default',
	    [{handler, 'ergw_aaa_static'}]},
	   {'Gx',
	    [{handler, 'ergw_aaa_gx'}]}
	  ]},

	 {apps,
	  [{default,
	    [{session, ['Default']},
	     {procedures, [{authenticate, []},
			   {authorize, []},
			   {start, []},
			   {interim, []},
			   {stop, []},
			   {{gx, 'CCR-Initial'},   ['Gx']},
			   {{gx, 'CCR-Update'},    ['Gx']},
			   {{gx, 'CCR-Terminate'}, ['Gx']}
			  ]}
	    ]}
	  ]}
	]).

%%%===================================================================
%%% Common Test callbacks
%%%===================================================================

all() ->
    [
     simple_session,
     handle_failure
    ].

init_per_suite(Config0) ->
    Config = [{handler_under_test, ?HUT} | Config0],

    application:load(ergw_aaa),
    [application:set_env(ergw_aaa, Key, Opts) || {Key, Opts} <- ?CONFIG],

    meck_init(Config),

    diameter_test_server:start(),
    {ok, _} = application:ensure_all_started(ergw_aaa),
    lager_common_test_backend:bounce(debug),

    case wait_for_diameter(?SERVICE, 10) of
	ok ->
	    Config;
	Other ->
	    end_per_suite(Config),
	    ct:fail(Other)
    end.

end_per_suite(Config) ->
    meck_unload(Config),
    application:stop(ergw_aaa),
    application:unload(ergw_aaa),
    diameter_test_server:stop(),
    ok.

init_per_testcase(Config) ->
    meck_reset(Config),
    Config.

end_per_testcase(_Config) ->
    ok.

%%%===================================================================
%%% Helper
%%%===================================================================

init_session(Session, _Config) ->
    Defaults =
	#{
	  '3GPP-GGSN-Address'       => {172,20,16,28},
	  '3GPP-IMEISV'             => <<82,21,50,96,32,80,30,0>>,
	  '3GPP-IMSI'               => <<"250071234567890">>,
	  %% '3GPP-Charging-Id'        => 3604013806,
	  %% '3GPP-IMSI-MCC-MNC'       => <<"25999">>,
	  %% '3GPP-GGSN-MCC-MNC'       => <<"25888">>,
	  '3GPP-MS-TimeZone'        => {128,1},
	  '3GPP-MSISDN'             => <<"46702123456">>,
	  %% '3GPP-NSAPI'              => 5,
	  %% '3GPP-PDP-Type'           => 'IPv4',
	  '3GPP-RAT-Type'           => 6,
	  '3GPP-SGSN-Address'       => {192,168,1,1},
	  '3GPP-SGSN-MCC-MNC'       => <<"26201">>,
	  '3GPP-Selection-Mode'     => 0,
	  '3GPP-User-Location-Info' => <<24,98,242,16,64,163,98,242,16,1,156,232,0>>,
	  'Called-Station-Id'       => <<"some.station.gprs">>,
	  %% 'Calling-Station-Id'      => <<"543148000012345">>,
	  'Framed-IP-Address'       => {10,106,14,227},
	  %% 'Framed-Protocol'         => 'GPRS-PDP-Context',
	  %% 'Multi-Session-Id'        => 1012552258277823040188863251876666193415858290601,
	  %% 'Username'                => <<"ergw">>,
	  %% 'Password'                => <<"ergw">>,
	  %% 'Service-Type'            => 'Framed-User',
	  %% 'Node-Id'                 => <<"PGW-001">>,
	  %% 'PDP-Context-Type'        => primary,
	  %% 'Charging-Rule-Base-Name' => <<"m2m0001">>,

	  %% '3GPP-GPRS-Negotiated-QoS-Profile' =>   <<11,146,31,147,150,64,64,255,
	  %% 					    255,255,255,17,1,1,64,64>>,
	  %% '3GPP-Allocation-Retention-Priority' => 2,
	  %% '3GPP-Charging-Characteristics' =>  <<8,0>>

	  'QoS-Information' =>
	      #{
		'QoS-Class-Identifier' => 8,
		'Max-Requested-Bandwidth-DL' => 0,
		'Max-Requested-Bandwidth-UL' => 0,
		'Guaranteed-Bitrate-DL' => 0,
		'Guaranteed-Bitrate-UL' => 0,
		'Allocation-Retention-Priority' =>
		    #{'Priority-Level' => 10,
		      'Pre-emption-Capability' => 1,
		      'Pre-emption-Vulnerability' => 0},
		'APN-Aggregate-Max-Bitrate-DL' => 84000000,
		'APN-Aggregate-Max-Bitrate-UL' => 8640000
	       }
	 },
    maps:merge(Defaults, Session).

%%%===================================================================
%%% Test cases
%%%===================================================================

simple_session() ->
    [{doc, "Simple Gx session"}].
simple_session(Config) ->
    Session = init_session(#{}, Config),
    GxOpts =
	#{'3GPP-IMSI' => <<"IMSI">>},

    Stats0 = get_stats(?SERVICE),

    {ok, SId} = ergw_aaa_session_sup:new_session(self(), Session),
    {ok, _Session1, Events1} =
	ergw_aaa_session:invoke(SId, GxOpts, {gx, 'CCR-Initial'}, [], false),
    ?match([{pcc, install, [_|_]}], Events1),

    GxTerm =
	#{'Termination-Cause' => ?'DIAMETER_BASE_TERMINATION-CAUSE_LOGOUT'},
    {ok, _Session2, _Events2} =
	ergw_aaa_session:invoke(SId, GxTerm, {gx, 'CCR-Terminate'}, [], false),

    Statistics = diff_stats(Stats0, get_stats(?SERVICE)),

    % check that client has sent CCR
    ?equal(2, proplists:get_value({{16777238, 272, 1}, send}, Statistics)),
    % check that client has received CCA
    ?equal(2, proplists:get_value({{16777238, 272, 0}, recv, {'Result-Code',2001}}, Statistics)),

    %% make sure nothing crashed
    meck_validate(Config),
    ok.

handle_failure(Config) ->
    Session = init_session(#{}, Config),
    GxOpts =
	#{'3GPP-IMSI' => <<"FAIL">>,
	  '3GPP-MSISDN' => <<"FAIL">>},

    Stats0 = get_stats(?SERVICE),

    {ok, SId} = ergw_aaa_session_sup:new_session(self(), Session),
    ?match({{fail, 3001}, _, _},
	   ergw_aaa_session:invoke(SId, GxOpts, {gx, 'CCR-Initial'}, [], false)),

    Statistics = diff_stats(Stats0, get_stats(?SERVICE)),

    % check that client has sent CCR
    ?equal(1, proplists:get_value({{16777238, 272, 1}, send}, Statistics)),
    % check that client has received CCA
    ?equal(1, proplists:get_value({{16777238, 272, 0}, recv, {'Result-Code',3001}}, Statistics)),

    %% make sure nothing crashed
    meck_validate(Config),
    ok.

%%%===================================================================
%%% Internal functions
%%%===================================================================
