defmodule Objex do
  defmacro __using__(_opts) do
    quote do
      import Objex, only: [class: 2, defm: 2]
    end
  end

  defmacro class(name, do: body) do
    quote do
      defmodule unquote(name) do
        use GenServer

        def start_link(ref) do
          GenServer.start_link(__MODULE__, %{},
                               name: {:via, Registry, {Objex.Registry, ref}})
        end

        def new do
          this = make_ref()
          {:ok, _pid} = __MODULE__.start_link(this)
          __MODULE__.on_init(this) # Calls the "constructor" (that isn't allowed any params btw).
          this
        end

        def on_init(_), do: nil

        defoverridable [on_init: 1]

        unquote(body)
      end
    end
  end

  defmacro defm(head, body) do
    {fn_name, [this | call_args] = args} = decompose_head(head) # Splits the head into `{function name, args}`
    {[_this | binding_names], bound_args} = bind_args(args) # Binds each arg to a unique name

    # Replaces the args with the bound args.
    # `fun(a, b, c)` becomes `fun(a = arg0, b = arg1, c = arg2)`.
    # This is to prevent a `CompileError: unbound variable _` when using `_` as an
    # argument (which happens because we're passing the args to `GenServer.call/2`).
    head = Macro.postwalk(head, fn
      {name, meta, old_args}
        when (name == fn_name and old_args == args) ->
          {name, meta, bound_args}
      other -> other
    end)

    # Replaces `this.name = 1` by `env = Map.put(env, :name, 1)` and `this.name` by
    # `Map.fetch!(env, :name)` (yep, you can't use names that don't exist).
    # `env` is the state of the process.
    body = Macro.prewalk(body, &update_env/1)

    # Allows to ignore guards on `handle_call/3`.
    # Replacing the head of handle_call to add the guard would be nicer but it seems
    # like it'd ruin my fun.
    fn_id = :erlang.term_to_binary(head)

    quote do
      # The "method" becomes a function that calls the process registered in
      # `Objex.Registry` (`this` contains the id -- the Reference created using
      # `make_ref()` in `new/0`).
      def unquote(head) do
        GenServer.call({:via, Registry, {Objex.Registry, unquote(this)}},
                       {unquote(fn_id), unquote(binding_names)})
      end

      # The body of the method goes here!
      def handle_call({unquote(fn_id), unquote(call_args)}, from, env) do
        result = unquote(body[:do])
        {:reply, result, env}
      end
    end
  end

  # Replaces instances of `this` to use the process' state.
  defp update_env({:=, _, [{{:., _, [{:this, _, nil}, name]}, _, []}, value]}) do
    quote do
      env = Map.put(env, unquote(name), unquote(value))
      unquote(value)
    end
  end
  defp update_env({{:., _, [{:this, _, nil}, name]}, _, []}),
    do: quote(do: Map.fetch!(env, unquote(name)))
  defp update_env(n), do: n

  # Returns a tuple containing the function name and its list of arguments.
  defp decompose_head({:when, _, [head | _]}),
    do: decompose_head(head)
  defp decompose_head(head),
    do: Macro.decompose_call(head)

  # Binds every argument to a unique name.
  defp bind_args([]), do: []
  defp bind_args(args) do
    args
    |> Enum.with_index()
    |> Enum.map(fn {arg, index} ->
      binding = Macro.var(:"arg#{index}", __MODULE__)

      {binding, quote(do: unquote(arg) = unquote(binding))}
    end)
    |> Enum.unzip
  end
end
