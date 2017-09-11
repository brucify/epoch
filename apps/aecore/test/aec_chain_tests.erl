-module(aec_chain_tests).

-include_lib("eunit/include/eunit.hrl").
-include("common.hrl").
-include("blocks.hrl").

fake_genesis_block() ->
    #block{height = 0,
           prev_hash = <<0:?BLOCK_HEADER_HASH_BYTES/unit:8>>,
           difficulty = 1,
           nonce = 0}.

top_test_() ->
    {foreach,
     fun() -> {ok, Pid} = aec_chain:start_link(fake_genesis_block()), Pid end,
     fun(_ChainPid) -> ok = aec_chain:stop() end,
     [{"Initialize chain with genesis block, then check top block with related state trees",
       fun() ->
               GB = fake_genesis_block(),
               ?assertEqual({ok, GB}, aec_chain:top_block()),

               {ok, Top} = aec_chain:top(),
               %% Check block apart from state trees.
               ?assertEqual(GB, Top#block{trees = GB#block.trees}),
               %% Check state trees in block.
               _ = Top#block.trees %% TODO Check.
       end}]}.

genesis_test_() ->
    {setup,
     fun() -> {ok, Pid} = aec_chain:start_link(fake_genesis_block()), Pid end,
     fun(_ChainPid) -> ok = aec_chain:stop() end,
     fun() ->
             GB = fake_genesis_block(),
             ?assertEqual({ok, GB}, aec_chain:top_block()),
             GH = aec_blocks:to_header(GB),
             ?assertEqual({ok, GH}, aec_chain:top_header()),

             ?assertEqual({ok, GH}, aec_chain:get_header_by_height(0)),
             ?assertEqual({ok, GB}, aec_chain:get_block_by_height(0)),

             {ok, GHH} = aec_blocks:hash_internal_representation(GB),
             ?assertEqual({ok, GH}, aec_chain:get_header_by_hash(GHH)),
             ?assertEqual({ok, GB}, aec_chain:get_block_by_hash(GHH))
     end}.

header_chain_test_() ->
    {setup,
     fun() -> {ok, Pid} = aec_chain:start_link(fake_genesis_block()), Pid end,
     fun(_ChainPid) -> ok = aec_chain:stop() end,
     fun() ->
             %% Check chain is at genesis.
             B0 = fake_genesis_block(),
             BH0 = aec_blocks:to_header(B0),
             ?assertEqual({ok, BH0}, aec_chain:top_header()),

             %% Check height of genesis - for readability of the test.
             0 = aec_headers:height(BH0),

             %% Add a couple of headers - not blocks - to the chain.
             {ok, B0H} = aec_blocks:hash_internal_representation(B0),
             BH1 = #header{height = 1, prev_hash = B0H},
             ?assertEqual(ok, aec_chain:insert_header(BH1)),
             {ok, B1H} = aec_headers:hash_internal_representation(BH1),
             BH2 = #header{height = 2, prev_hash = B1H},
             ?assertEqual(ok, aec_chain:insert_header(BH2)),

             %% Check highest header.
             ?assertEqual({ok, BH2}, aec_chain:top_header()),
             %% Check heighest known block - still genesis.
             ?assertEqual({ok, B0}, aec_chain:top_block()),

             %% Check by hash.
             ?assertEqual({ok, BH0}, aec_chain:get_header_by_hash(B0H)),
             ?assertEqual({ok, B0}, aec_chain:get_block_by_hash(B0H)),
             ?assertEqual({ok, BH1}, aec_chain:get_header_by_hash(B1H)),
             ?assertEqual({error, {block_not_found, {top_header, BH2}}},
                          aec_chain:get_block_by_hash(B1H)),
             {ok, B2H} = aec_headers:hash_internal_representation(BH2),
             ?assertEqual({ok, BH2}, aec_chain:get_header_by_hash(B2H)),
             ?assertEqual({error, {block_not_found, {top_header, BH2}}},
                          aec_chain:get_block_by_hash(B2H)),

             %% Check by height.
             ?assertEqual({ok, BH0}, aec_chain:get_header_by_height(0)),
             ?assertEqual({ok, B0}, aec_chain:get_block_by_height(0)),
             ?assertEqual({ok, BH1}, aec_chain:get_header_by_height(1)),
             ?assertEqual({error, {block_not_found, {top_header, BH2}
                                  }}, aec_chain:get_block_by_height(1)),
             ?assertEqual({ok, BH2}, aec_chain:get_header_by_height(2)),
             ?assertEqual({error, {block_not_found, {top_header, BH2}
                                  }}, aec_chain:get_block_by_height(2)),
             ?assertEqual({error, {chain_too_short, {{chain_height, 2},
                                                     {top_header, BH2}}
                                  }}, aec_chain:get_header_by_height(3)),
             ?assertEqual({error, {chain_too_short, {{chain_height, 2},
                                                     {top_header, BH2}}
                                  }}, aec_chain:get_block_by_height(3))
     end}.

block_chain_test_() ->
    {foreach,
     fun() -> {ok, Pid} = aec_chain:start_link(fake_genesis_block()), Pid end,
     fun(_ChainPid) -> ok = aec_chain:stop() end,
     [{"Build chain with genesis block plus 2 headers, then store block corresponding to top header",
       fun() ->
               %% Check chain is at genesis.
               B0 = fake_genesis_block(),
               BH0 = aec_blocks:to_header(B0),
               ?assertEqual({ok, BH0}, aec_chain:top_header()),

               %% Check height of genesis - for readability of the test.
               0 = aec_headers:height(BH0),

               %% Add a couple of headers - not blocks - to the chain.
               {ok, B0H} = aec_blocks:hash_internal_representation(B0),
               B1 = #block{height = 1, prev_hash = B0H},
               BH1 = aec_blocks:to_header(B1),
               ?assertEqual(ok, aec_chain:insert_header(BH1)),
               {ok, B1H} = aec_headers:hash_internal_representation(BH1),
               B2 = #block{height = 2, prev_hash = B1H},
               BH2 = aec_blocks:to_header(B2),
               ?assertEqual(ok, aec_chain:insert_header(BH2)),

               %% Add one block corresponding to a header already in the chain.
               ?assertEqual(ok, aec_chain:write_block(B2)),

               %% Check highest header.
               ?assertEqual({ok, BH2}, aec_chain:top_header()),
               %% Check heighest known block.
               ?assertEqual({ok, B2}, aec_chain:top_block()),

               %% Check by hash.
               ?assertEqual({ok, BH0}, aec_chain:get_header_by_hash(B0H)),
               ?assertEqual({ok, B0}, aec_chain:get_block_by_hash(B0H)),
               ?assertEqual({ok, BH1}, aec_chain:get_header_by_hash(B1H)),
               ?assertEqual({error, {block_not_found, {top_header, BH2}}},
                            aec_chain:get_block_by_hash(B1H)),
               {ok, B2H} = aec_headers:hash_internal_representation(BH2),
               ?assertEqual({ok, BH2}, aec_chain:get_header_by_hash(B2H)),
               ?assertEqual({ok, B2}, aec_chain:get_block_by_hash(B2H)),

               %% Check by height.
               ?assertEqual({ok, BH0}, aec_chain:get_header_by_height(0)),
               ?assertEqual({ok, B0}, aec_chain:get_block_by_height(0)),
               ?assertEqual({ok, BH1}, aec_chain:get_header_by_height(1)),
               ?assertEqual({error, {block_not_found, {top_header, BH2}
                                    }}, aec_chain:get_block_by_height(1)),
               ?assertEqual({ok, BH2}, aec_chain:get_header_by_height(2)),
               ?assertEqual({ok, B2}, aec_chain:get_block_by_height(2)),
               ?assertEqual({error, {chain_too_short, {{chain_height, 2},
                                                       {top_header, BH2}}
                                    }}, aec_chain:get_header_by_height(3)),
               ?assertEqual({error, {chain_too_short, {{chain_height, 2},
                                                       {top_header, BH2}}
                                    }}, aec_chain:get_block_by_height(3))
       end},
     {"Build chain with genesis block plus 2 headers, then store block corresponding to header before top header",
       fun() ->
               %% Check chain is at genesis.
               B0 = fake_genesis_block(),
               BH0 = aec_blocks:to_header(B0),
               ?assertEqual({ok, BH0}, aec_chain:top_header()),

               %% Check height of genesis - for readability of the test.
               0 = aec_headers:height(BH0),

               %% Add a couple of headers - not blocks - to the chain.
               {ok, B0H} = aec_blocks:hash_internal_representation(B0),
               B1 = #block{height = 1, prev_hash = B0H},
               BH1 = aec_blocks:to_header(B1),
               ?assertEqual(ok, aec_chain:insert_header(BH1)),
               {ok, B1H} = aec_headers:hash_internal_representation(BH1),
               B2 = #block{height = 2, prev_hash = B1H},
               BH2 = aec_blocks:to_header(B2),
               ?assertEqual(ok, aec_chain:insert_header(BH2)),

               %% Add one block corresponding to a header already in the chain.
               ?assertEqual(ok, aec_chain:write_block(B1)),

               %% Check highest header.
               ?assertEqual({ok, BH2}, aec_chain:top_header()),
               %% Check heighest known block.
               ?assertEqual({ok, B1}, aec_chain:top_block()),

               %% Check by hash.
               ?assertEqual({ok, BH0}, aec_chain:get_header_by_hash(B0H)),
               ?assertEqual({ok, B0}, aec_chain:get_block_by_hash(B0H)),
               ?assertEqual({ok, BH1}, aec_chain:get_header_by_hash(B1H)),
               ?assertEqual({ok, B1}, aec_chain:get_block_by_hash(B1H)),
               {ok, B2H} = aec_headers:hash_internal_representation(BH2),
               ?assertEqual({ok, BH2}, aec_chain:get_header_by_hash(B2H)),
               ?assertEqual({error, {block_not_found, {top_header, BH2}}},
                            aec_chain:get_block_by_hash(B2H)),

               %% Check by height.
               ?assertEqual({ok, BH0}, aec_chain:get_header_by_height(0)),
               ?assertEqual({ok, B0}, aec_chain:get_block_by_height(0)),
               ?assertEqual({ok, BH1}, aec_chain:get_header_by_height(1)),
               ?assertEqual({ok, B1}, aec_chain:get_block_by_height(1)),
               ?assertEqual({ok, BH2}, aec_chain:get_header_by_height(2)),
               ?assertEqual({error, {block_not_found, {top_header, BH2}
                                    }}, aec_chain:get_block_by_height(2)),
               ?assertEqual({error, {chain_too_short, {{chain_height, 2},
                                                       {top_header, BH2}}
                                    }}, aec_chain:get_header_by_height(3)),
               ?assertEqual({error, {chain_too_short, {{chain_height, 2},
                                                       {top_header, BH2}}
                                    }}, aec_chain:get_block_by_height(3))
       end}]}.

%% Cover unhappy paths not covered in any other tests.
unhappy_paths_test_() ->
    {foreach,
     fun() -> {ok, Pid} = aec_chain:start_link(fake_genesis_block()), Pid end,
     fun(_ChainPid) -> ok = aec_chain:stop() end,
     [{"Get header by hash - case not found",
       fun() ->
               %% Check chain is at genesis.
               B0 = fake_genesis_block(),
               BH0 = aec_blocks:to_header(B0),
               ?assertEqual({ok, BH0}, aec_chain:top_header()),

               %% Check height of genesis - for readability of the test.
               0 = aec_headers:height(BH0),

               %% Add a header to the chain.
               {ok, B0H} = aec_blocks:hash_internal_representation(B0),
               BH1 = #header{height = 1, prev_hash = B0H},
               ?assertEqual(ok, aec_chain:insert_header(BH1)),

               %% Attempt to lookup header not added to chain.
               {ok, B1H} = aec_headers:hash_internal_representation(BH1),
               BH2 = #header{height = 2, prev_hash = B1H},
               {ok, B2H} = aec_headers:hash_internal_representation(BH2),

               %% Attempt to get by hash header not added to chain.
               ?assertEqual({error, {header_not_found, {top_header, BH1}}},
                            aec_chain:get_header_by_hash(B2H))
       end}]}.

generate_block_chain_by_difficulties_with_nonce(
  GenesisBlock, [GenesisDifficulty | OtherDifficulties], Nonce) ->
    %% Check height of genesis - for readability.
    0 = aec_blocks:height(GenesisBlock),
    %% Check difficulty of genesis - for readability.
    GenesisDifficulty = aec_blocks:difficulty(GenesisBlock),
    lists:reverse(
      lists:foldl(
        fun(D, [PrevB | _] = BC) ->
                {ok, PrevHH} = aec_blocks:hash_internal_representation(PrevB),
                B = #block{height = 1 + aec_blocks:height(PrevB),
                           prev_hash = PrevHH,
                           difficulty = D,
                           nonce = Nonce},
                [B | BC]
        end,
        [GenesisBlock],
        OtherDifficulties)).

header_chain_from_block_chain(BC) ->
    lists:map(fun aec_blocks:to_header/1, BC).

longest_header_chain_test_() -> %% TODO Check top.
    {foreach,
     fun() -> {ok, Pid} = aec_chain:start_link(fake_genesis_block()), Pid end,
     fun(_ChainPid) -> ok = aec_chain:stop() end,
     [{"The alternative header chain has a different genesis hence its amount of work cannot be compared",
       fun() ->
               %% Check chain is at genesis.
               B0 = fake_genesis_block(),
               BH0 = aec_blocks:to_header(B0),
               ?assertEqual({ok, BH0}, aec_chain:top_header()),

               %% Check height of genesis - for readability of the test.
               0 = aec_headers:height(BH0),
               %% Check nonce of genesis - for readability of the test.
               0 = aec_headers:nonce(BH0),

               %% Generate the alternative header chain from a
               %% different genesis.
               HA0 = BH0#header{nonce = 1},
               {ok, HA0H} = aec_headers:hash_internal_representation(HA0),
               HA1 = #header{height = 1, prev_hash = HA0H},
               AltHC = [HA0, HA1],

               %% Attempt to determine chain with more work -
               %% specifying full header chain.
               ?assertEqual({error, {different_genesis, {genesis_header, BH0}}},
                            aec_chain:has_more_work(AltHC)),
               %% Attempt to determine chain with more work -
               %% specifying header chain removing old ancestors.
               ?assertEqual({error, {no_common_ancestor, {top_header, BH0}}},
                            aec_chain:has_more_work(
                              [HA1] = lists:nthtail(1, AltHC)))
       end},
      {"The alternative header chain does not have more work - case alternative chain is less high",
       fun() ->
               %% Generate the two header chains.
               B0 = fake_genesis_block(),
               MainBC = [B0, _, _] = generate_block_chain_by_difficulties_with_nonce(B0, [1, 2, 2], 111),
               AltBC = [B0, _] = generate_block_chain_by_difficulties_with_nonce(B0, [1, 3], 222),
               MainHC = [H0, _, HM2] = header_chain_from_block_chain(MainBC),
               AltHC = [H0, _] = header_chain_from_block_chain(AltBC),

               %% Check chain is at genesis.
               ?assertEqual({ok, H0}, aec_chain:top_header()),

               %% Insert the main chain.
               lists:foreach(
                 fun(H) -> ok = aec_chain:insert_header(H) end,
                 lists:nthtail(1, MainHC)),

               %% Check top is main chain.
               ?assertEqual({ok, HM2}, aec_chain:top_header()),

               %% Determine chain with more work - specifying full header chain.
               %% TODO ?assertEqual({ok, {false, {top_header, HM2}}},
               %% TODO              aec_chain:has_more_work(AltHC)),
               %% TODO Attempt to determine chain with more work -
               %% specifying header chain removing old ancestors.
               %% TODO ?assertEqual({ok, {false, {top_header, HM2}}}, aec_chain:has_more_work(lists:nthtail(1, AltHC))),

               %% Give up updating chain because existing chain has more work.
               ok
       end},
      {"The alternative header chain does not have more work - case alternative chain is higher",
       fun() ->
               ?debugMsg("Known: 1 3; Alternative: 1 1 1."),
               ?debugMsg("TODO Start from chain e.g. with 3 headers, identify alternative chain, determine chain with more work, give up updating chain because existing chain has larger amount of work.")
       end},
      {"The alternative chain has the same amount of work, hence is to be ignored because received later",
       fun() ->
               ?debugMsg("Known: 1 2; Alternative: 1 1 1."),
               ?debugMsg("TODO")
       end},
      {"The alternative header chain has more work - case alternative chain is higher",
       fun() ->
               ?debugMsg("Known: 1 2; Alternative: 1 1 1 1."),
               ?debugMsg("TODO Start from chain e.g. with 3 headers, identify alternative chain, determine chain with more work, force chain. Check that headers in previous chain cannot be retrieved by hash (i.e. chain service minimizes used storage, while exposing consistent view of chain).")
       end},
      {"The alternative header chain has more work - case alternative chain is less high",
       fun() ->
               ?debugMsg("Known: 1 1 1; Alternative: 1 3."),
               ?debugMsg("TODO Start from chain e.g. with 3 headers, identify alternative chain, determine chain with more work, force chain. Check that headers in previous chain cannot be retrieved by hash (i.e. chain service minimizes used storage, while exposing consistent view of chain).")
       end},
      {"The alternative header chain has more work, but results in sub-optimal choice because of concurrent insertion",
       fun() ->
               ?debugMsg("TODO Start from chain e.g. with 3 headers, identify alternative chain, determine chain with more work. Concurrent actor increases amount of work in tracked chain, initial actor forces chain hence tracked chain is sub-optimal. Check that headers in previous chain cannot be retrieved by hash (i.e. chain service minimizes used storage, while exposing consistent view of chain). XXX This test has the main aim of clarifying design of whether chain service shall reject forcing chain with smaller amount of work.")
       end}]}.

longest_block_chain_test_() -> %% TODO Check top.
    {foreach,
     fun() -> {ok, Pid} = aec_chain:start_link(fake_genesis_block()), Pid end,
     fun(_ChainPid) -> ok = aec_chain:stop() end,
     [{"The alternative block chain has more work - case alternative chain with all blocks",
       fun() ->
               ?debugMsg("TODO Start from chain e.g. with 3 headers, identify alternative chain, determine chain with more work, force chain with all blocks. Check that headers and blocks in previous chain cannot be retrieved by hash (i.e. chain service minimizes used storage, while exposing consistent view of chain).")
       end},
      {"The alternative block chain has more work - case alternative chain with only block corresponding to top header",
       fun() ->
               ?debugMsg("TODO Start from chain e.g. with 3 headers, identify alternative chain, determine chain with more work, force chain with only top block. Check that headers and blocks in previous chain cannot be retrieved by hash (i.e. chain service minimizes used storage, while exposing consistent view of chain).")
       end},
      {"The alternative block chain has more work - case alternative chain with only block corresponding to header before top header",
       fun() ->
               ?debugMsg("TODO Start from chain e.g. with 3 headers, identify alternative chain, determine chain with more work, force chain with only block before top. Check that headers and blocks in previous chain cannot be retrieved by hash (i.e. chain service minimizes used storage, while exposing consistent view of chain).")
       end}]}.

%% TODO reorganisation
