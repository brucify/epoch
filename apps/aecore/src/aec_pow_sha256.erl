%%%=============================================================================
%%% @copyright 2017, Aeternity Anstalt
%%% @doc
%%%    Module dealing with SHA256 Proof of Work calculation and hash generation
%%% @end
%%%=============================================================================
-module(aec_pow_sha256).

-export([generate/3,
         generate/4,
         recalculate_difficulty/3,
         pick_nonce/0]).

-ifdef(TEST).
-compile(export_all).
-endif.

-include("sha256.hrl").

%% 10^24, approx. 2^80
-define(NONCE_RANGE, 1000000000000000000000000).

-type pow_result() :: {ok, integer()} | {'error', 'generation_count_exhausted'}.

-export_type([pow_result/0]).

%%%=============================================================================
%%% API
%%%=============================================================================

%%------------------------------------------------------------------------------
%% Same as generate/4, but with random initial nonce
%%------------------------------------------------------------------------------
-spec generate(Data :: binary(), Difficulty :: aec_sha256:sci_int(),
               Count :: integer()) -> pow_result().
generate(Data, Difficulty, Count) ->
    %% Pick a nonce between 0 and 10^24 (approx. 2^80)
    Nonce = ?MODULE:pick_nonce(),
    generate(Data, Difficulty, Nonce, Count).

%%------------------------------------------------------------------------------
%% Generate a nonce value that, when used in hash calculation of 'Data', results in
%% a smaller value than the difficulty. Return {error, not_found} if the condition
%% is still not satisfied after trying 'Count' times with incremented nonce values.
%% Start generation from initial passed nonce.
%%------------------------------------------------------------------------------
-spec generate(Data :: binary(), Difficulty :: aec_sha256:sci_int(),
               Nonce :: integer(), Count :: integer()) -> pow_result().
generate(_Data, _Difficulty, Nonce, 0) ->
    %% Count exhausted: fail
    {error, generation_count_exhausted, Nonce};
generate(Data, Difficulty, Nonce, Count) ->
    Hash = aec_sha256:hash(<<Data/binary, Difficulty:16, Nonce:?HASH_BITS>>),
    case aec_sha256:binary_to_scientific(Hash) of
        HD when HD < Difficulty ->
            %% Hash satisfies condition: return nonce
            %% Note: only the trailing 32 bytes of it are actually used in
            %% hash calculation
            {ok, Nonce};
        _ ->
            %% Keep trying
            generate(Data, Difficulty, Nonce + 1, Count - 1)
    end.

%%------------------------------------------------------------------------------
%% Adjust difficulty so that generation of new blocks proceeds at the expected pace
%%------------------------------------------------------------------------------
-spec recalculate_difficulty(aec_sha256:sci_int(), integer(), integer()) ->
                                    aec_sha256:sci_int().
recalculate_difficulty(Difficulty, Expected, Actual) ->
    DiffInt = aec_sha256:scientific_to_integer(Difficulty),
    aec_sha256:integer_to_scientific(max(1, DiffInt * Expected div Actual)).

%%%=============================================================================
%%% Internal functions
%%%=============================================================================
pick_nonce() ->
    rand:uniform(?NONCE_RANGE).
