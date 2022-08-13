defmodule Pingado do
  @kind :"$kind"
  @meta :"~meta"
  @span :"$span"

  defmacro kind(), do: quote(do: unquote(@kind))
  defmacro meta(), do: quote(do: unquote(@meta))
  defmacro span(), do: quote(do: unquote(@span))

  @spec start_trace() :: :ok
  defdelegate start_trace(), to: :snabbkaffe
  @spec stop() :: :ok
  defdelegate stop(), to: :snabbkaffe

  @spec subscribe((%{} -> boolean()), pos_integer(), pos_integer() | :infinity) ::
          {:ok, reference()}
  defdelegate subscribe(match_fn, n_events, timeout), to: :snabbkaffe
  @spec receive_events(reference()) :: {:ok | :timeout, [%{}]}
  defdelegate receive_events(sub_ref), to: :snabbkaffe

  if Mix.env() == :test do
    defmacro tp(level \\ :debug, kind, event) do
      quote do
        :snabbkaffe.tp(
          fn -> :ok end,
          unquote(level),
          unquote(kind),
          unquote(event)
        )
      end
    end
  else
    defmacro tp(_level \\ :debug, _kind, _event) do
      quote(do: :ok)
    end
  end

  defmacro tp_span(level \\ :debug, kind, event, do: code) do
    res = Macro.unique_var(:res, __CALLER__.module)

    quote do
      Pingado.tp(unquote(level), unquote(kind), Map.put(unquote(event), unquote(@span), :start))
      unquote(res) = unquote(code)

      Pingado.tp(
        unquote(level),
        unquote(kind),
        Map.put(unquote(event), unquote(@span), {:complete, unquote(res)})
      )

      unquote(res)
    end
  end

  defmacro check_trace(bucket \\ quote(do: %{}), do: run, after: check) do
    quote do
      case :snabbkaffe.run(
             unquote(bucket),
             fn -> unquote(run) end,
             unquote(check)
           ) do
        true ->
          true

        :ok ->
          true

        {:error, {:panic, kind, args}} ->
          raise ExUnit.AssertionError, expr: args, message: inspect(kind)

        {:error, {:panic, args = %{unquote(@kind) => kind}}} ->
          raise ExUnit.AssertionError, expr: args, message: inspect(kind)

        res ->
          raise ExUnit.AssertionError, expr: res, message: "Unexpected result"
      end
    end
  end

  defmacro causality(trace, pat1, pat2, guard \\ true) do
    quote do
      try do
        :snabbkaffe.causality(
          false,
          Pingado.match_event(unquote(pat1)),
          Pingado.match_event(unquote(pat2)),
          Pingado.match2(unquote(pat1), unquote(pat2), unquote(guard)),
          unquote(trace)
        )
      rescue
        e in ErlangError ->
          %ErlangError{original: {:panic, args = %{unquote(@kind) => kind}}} = e

          args =
            args
            |> Map.drop([unquote(@kind)])
            |> Keyword.new()

          reraise ExUnit.AssertionError, [message: to_string(kind), args: args], __STACKTRACE__
      end
    end
  end

  defmacro strict_causality(trace, pat1, pat2, guard \\ true) do
    quote do
      try do
        :snabbkaffe.causality(
          true,
          Pingado.match_event(unquote(pat1)),
          Pingado.match_event(unquote(pat2)),
          Pingado.match2(unquote(pat1), unquote(pat2), unquote(guard)),
          unquote(trace)
        )
      rescue
        e in ErlangError ->
          %ErlangError{original: {:panic, args = %{unquote(@kind) => kind}}} = e

          args =
            args
            |> Map.drop([unquote(@kind)])
            |> Keyword.new()

          reraise ExUnit.AssertionError, [message: to_string(kind), args: args], __STACKTRACE__
      end
    end
  end

  defmacro block_until(pattern, timeout, back_in_time \\ :infinity) do
    quote do
      :snabbkaffe.block_until(
        Pingado.match_event(unquote(pattern)),
        unquote(timeout),
        unquote(back_in_time)
      )
    end
  end

  defmacro wait_async_action(pattern, timeout \\ :infinity, do: action) do
    quote do
      :snabbkaffe.wait_async_action(
        fn -> unquote(action) end,
        Pingado.match_event(unquote(pattern)),
        unquote(timeout)
      )
    end
  end

  defmacro inject_crash(pattern, strategy, reason \\ :notmyday) do
    quote do
      :snabbkaffe_nemesis.inject_crash(
        Pingado.match_event(unquote(pattern)),
        unquote(strategy),
        unquote(reason)
      )
    end
  end

  defmacro match_event(pat) do
    quote do
      fn evt ->
        match?(unquote(pat), evt)
      end
    end
  end

  defmacro match2(pat1, pat2, guard) do
    quote do
      fn evt1, evt2 ->
        with unquote(pat1) <- evt1,
             unquote(pat2) <- evt2 do
          unquote(guard)
        else
          _ -> false
        end
      end
    end
  end

  defmacro retry(timeout, n, do: code) do
    quote do
      :snabbkaffe.retry(
        unquote(timeout),
        unquote(n),
        fn ->
          unquote(code)
        end
      )
    end
  end
end
