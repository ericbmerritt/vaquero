defmodule Vaquero.Handler do

  defrecord Handler, [name: nil,
                      parent: nil,
                      patterns: nil,
                      bindings: nil,
                      opts: nil,
                      route: nil,
                      handlers: ListDict.new]



  def new(module_name, route, opts) do
    count = get_count(module_name)
    {patterns, bindings} = Vaquero.Router.parse_route(route)
    name = create_name(module_name, count)
    Handler[name: name,
            parent: module_name,
            route: route,
            patterns: patterns,
            bindings: bindings,
            opts: opts]
  end

  def add_handler(t = Handler[handlers: handlers, route: route], opts) do
    method = opts[:type]
    method_handler = Dict.get(handlers, method) || ListDict.new
    content_type = opts[:content_type]
    if Dict.has_key?(method_handler, content_type) do
      raise ExistingHandler, route: route, type: :delete, detail: content_type
    else
      handlers = Dict.put(handlers, method,
                          Dict.put(method_handler, content_type, opts))
      t.handlers(handlers)
    end
  end

  defp create_name(module_name, count) do
    :erlang.list_to_atom('#{module_name}.REST#{count}')
  end

  defp get_count(module) do
    count = Module.get_attribute(module, :vaquero_handler_count)
    Module.put_attribute(module, :vaquero_handler_count, count + 1)
    count
  end

  def content_type_to_binary(:json) do
    "application/json"
  end
  def content_type_to_binary(:html) do
    "text/html"
  end
  def content_type_to_binary({t1, t2}) do
    "#{t1}/#{t2}"
  end

  defp gen_bindings(Handler[bindings: bindings], options) do
    Enum.filter_map(bindings,
                    is_not_hidden?(&1, options),
                    fn(binding) ->
                        quote do
                          {var!(unquote(binding)), req} =
                            :cowboy_req.binding(unquote(binding),
                                                req,
                                                nil)
                        end
                    end)
  end

  defp is_not_hidden?(value, opts) do
    hidden = opts[:hide] || []
    Enum.all?(hidden,
              fn({pos, _, _}) ->
                  value != pos
              end)
  end

  def gen_content_type_case(t, {_, options}) do
    type = options[:type]
    content_type = options[:content_type]
    name = :erlang.list_to_atom('handle_#{type}')
    binary_content_type = content_type_to_binary(content_type)
    bindings = gen_bindings(t, options)
    body = options[:do]
    req = options[:req] || (quote do: req)
    quote do
      def unquote(name)(unquote(req), state, unquote(binary_content_type)) do
        unquote(bindings)
        result = unquote(body)

        Vaquero.Runtime.handle_output(unquote(req),
                                      state,
                                      unquote(content_type),
                                      unquote(binary_content_type),
                                      result)

      end
    end
  end

  defp default_reply() do
    quote do
      {:ok, :cowboy_req.reply(405, [], <<>>, req), state}
    end
  end

  defp gen_handler_clause(_, nil) do
    default_reply()
  end
  defp gen_handler_clause(t = Handler[handlers: all_handlers], method) do
    handlers = all_handlers[method]
    name = :erlang.list_to_atom('handle_#{method}')
    default = default_reply()
    if handlers do
      method_defs = Enum.map(handlers, gen_content_type_case(t, &1))
      quote do
        unquote(method_defs)
        def unquote(name)(req, state, _) do
          {:ok, :cowboy_req.reply(404, [], <<>>, req), state}
        end
      end
    else
      quote do
        def unquote(name)(req, state, _) do
          unquote(default)
        end
      end
    end
  end

  def build(t = Handler[name: name], _env) do
    get = gen_handler_clause(t, :get)
    put = gen_handler_clause(t, :put)
    head = gen_handler_clause(t, :head)
    patch = gen_handler_clause(t, :patch)
    post = gen_handler_clause(t, :post)
    delete = gen_handler_clause(t, :delete)
    options = gen_handler_clause(t, :options)
    default = default_reply()

    quote do
      defmodule unquote(name) do

        def init(_transport, req, []) do
          {:ok, req, nil}
        end

        unquote(get)
        unquote(put)
        unquote(head)
        unquote(patch)
        unquote(post)
        unquote(delete)
        unquote(options)

        def handle(req, state) do
          {headers, req} = :cowboy_req.headers(req)
          content_type = Dict.get(headers, "content_type") || <<"application/json">>

          case :cowboy_req.method(req) do
            {"GET", req} ->
              handle_get(req, state, content_type)
            {"PUT", req} ->
              handle_put(req, state, content_type)
            {"HEAD", req} ->
              handle_head(req, state, content_type)
            {"PATCH", req} ->
              handle_patch(req, state, content_type)
            {"POST", req} ->
              handle_post(req, state, content_type)
            {"DELETE", req} ->
              handle_delete(req, state, content_type)
            {"OPTIONS", req} ->
              handle_options(req, state, content_type)
            {_, req} ->
              unquote(default)
          end
        end

        def terminate(_reason, _req, _state) do
          :ok
        end
      end
    end
  end
end
