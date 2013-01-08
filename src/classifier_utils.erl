-module(classifier_utils).

-export([get_files/1, get_tokenized/2, get_tokenized/1, get_text_tokenized/1, count_tokens/1, 
        calculate_probabilities/5, get_ocurrences/2, add_token_appearances_from_files/3, add_token_appearances/2,
        delete_token_appearances/2]).

-spec get_files(string()) -> [{pos | neg, string()}].
get_files(FolderName) ->
  SubDirs = [{Tag,filename:join([FolderName, Sub])} || {Sub,Tag} <- [{"neg", neg},{"pos", pos}]],
  Files = [[{Tag,File} || File <- filelib:wildcard(filename:join([Dir,"*.txt"]))] || {Tag,Dir} <- SubDirs],
  lists:foldl(fun(More, Accum) -> More ++ Accum end, [], Files).

-spec add_token_appearances_from_files(pos | neg, [{pos | neg, string()}], dict()) -> dict().
add_token_appearances_from_files(Tag, Files, Tokens) ->
  TokenList = get_tokenized(Tag, Files),
  add_token_appearances(TokenList, Tokens).

-spec add_token_appearances([string()], dict()) -> dict().
add_token_appearances(TokenList, Tokens) ->
  lists:foldl(fun(Token, TokenDict) ->
    case dict:find(Token, TokenDict) of
      {ok, Count} -> dict:store(Token, Count+1, TokenDict);
      error -> dict:store(Token, 1, TokenDict)
    end
  end, Tokens, TokenList).

-spec delete_token_appearances([string()], dict()) -> dict().
delete_token_appearances(TokenList, Tokens) ->
  lists:foldl(fun(Token, TokenDict) ->
    case dict:find(Token, TokenDict) of
      {ok, 1} -> dict:erase(Token, TokenDict);
      {ok, Count} -> dict:store(Token, Count-1, TokenDict);
      error -> TokenDict
    end
  end, Tokens, TokenList).

-spec get_tokenized(pos | neg, [{pos | neg, string()}]) -> [string()].
get_tokenized(Tag, Files) ->
  lists:flatmap(fun({FileTag, Filename}) when FileTag == Tag ->
    get_tokenized(Filename);
  ({_, _}) -> []
  end, Files).

-spec get_tokenized(string()) -> [string()].
get_tokenized(FileName) -> {ok, Data} = file:read_file(FileName), re:split(Data, "[^a-zA-Z0-9]+").

-spec get_text_tokenized(string()) -> [string()].
get_text_tokenized(Text) -> re:split(string:strip(Text), "[^a-zA-Z0-9]+").


-spec calculate_probabilities([string()], [string()], pos_integer(), float(), float()) -> dict().
calculate_probabilities(PosTokens, NegTokens, MinAppearances, MinProb, MaxProb) ->
  Tokens = lists:usort([ Token || {Token, _Count} <- dict:to_list(PosTokens)] ++ 
                       [ Token || {Token, _Count} <- dict:to_list(NegTokens)]),
  LengthPosTokens = dict:size(PosTokens),
  LengthNegTokens = dict:size(NegTokens),

  lists:foldl(fun(Token, Dict) ->
    PosOcurrences = get_ocurrences(Token, PosTokens),
    NegOcurrences = get_ocurrences(Token, NegTokens), 

    case (PosOcurrences + NegOcurrences) < MinAppearances of
      true -> Dict;
      false ->
        % PosResult = min(1, 2 * PosOcurrences / LengthPosTokens),
        PosResult = try PosOcurrences / LengthPosTokens catch _:_ -> 0 end,
        NegResult = try NegOcurrences / LengthNegTokens catch _:_ -> 0 end,
        NegProbability = max(MinProb, min(MaxProb, NegResult / (PosResult + NegResult))),
        dict:store(Token, NegProbability, Dict)
    end
  end, dict:new(), Tokens).

count_tokens(Tokens) ->
  lists:foldl(fun(Token, Dict) -> 
    case dict:find(Token, Dict) of
      {ok, Count} -> dict:store(Token, Count+1, Dict);
      error -> dict:store(Token, 1, Dict)
    end 
  end, dict:new(), Tokens).

get_ocurrences(Token, TokenCounts) ->
  case dict:find(Token, TokenCounts) of
    {ok, Value} -> Value;
    error -> 0
  end.