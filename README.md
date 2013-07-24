# Vaquero

`output`, `{status, output}`, `{status, headers, output}`
    defmodule RestRouter do
        use Vaquero, authorize: authorized?



        def authorized?(req, state) do
            # everybody party!
            true
        end

        get "/", content_type: :json, req: req do

        end

        get "/", content_type: :html, req: req do

        end


Data Format
-----------

    Elixir                        JSON            Elixir
    ==========================================================================

    :null                      -> null           -> :null
    :nil                       -> "nil"          -> :nil
    true                       -> true           -> true
    false                      -> false          -> false
    'hi'                       -> [104, 105]     -> 'hi'
    "hi"                       -> "hi"           -> "hi"
    :hi                        -> "hi"           -> "hi"
    1                          -> 1              -> 1
    1.25                       -> 1.25           -> 1.25
    []                         -> []             -> []
    [true, 1.0]                -> [true, 1.0]    -> [true, 1.0]
    {[]}                       -> {}             -> {[]}
    {[{:foo, :bar}]}           -> {"foo": "bar"} -> {[{"foo", "bar"}]}
    {[{"foo", "bar"}]}         -> {"foo": "bar"} -> {[{"foo", "bar"}]}
