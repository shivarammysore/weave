-module(flowcompiler).

-export([setup_flow/2]).

%% @doc Set up a net flow from `Source' to `Destination'.
%%
%% Determine what flow rules are required to route IP packets from
%% `Source' to `Destination' and back.  Install the flow rules in the
%% switches, and publish them in Dobby.
%%
%% `Source' and `Destination' are binaries that name endpoints present
%% in Dobby.
-spec setup_flow(binary(), binary()) -> _.
setup_flow(Source, Destination)
  when is_binary(Source), is_binary(Destination) ->
    FlowRules = fc_find_path:path_flow_rules(Source, Destination),
    lists:foreach(fun send_flow_rules/1, FlowRules),
    FlowModIds =
        lists:map(
          fun(DatapathFlowMod) ->
                  {ok, FlowModId} =
                      dobby_oflib:publish_dp_flow_mod(<<"flowcompiler">>, DatapathFlowMod),
                  FlowModId
          end, FlowRules),
    dobby_oflib:publish_net_flow(
      <<"flowcompiler">>,
      Source,
      Destination,
      FlowModIds).

send_flow_rules({Dpid, OFVersion, {Matches, Instr, Opts}}) when is_binary(Dpid) ->
    Msg = of_msg_lib:flow_add(OFVersion, Matches, Instr, Opts),
    {ok, noreply} = ofs_handler:sync_send(binary_to_list(Dpid), Msg),
    ok.