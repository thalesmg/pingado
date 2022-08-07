defmodule PingadoTest do
  use ExUnit.Case

  import Pingado,
    only: [
      check_trace: 1,
      check_trace: 2,
      tp: 2,
      tp: 3,
      tp_span: 4,
      causality: 4,
      wait_async_action: 3,
      inject_crash: 3
    ]

  test "check_trace" do
    check_trace do
      x = 1
      tp(:debug, :oxe, %{x: x})
      {:ok, x + 3}
    after
      [
        fn _trace ->
          :ok
        end,
        fn _res, _trace ->
          :ok
        end
      ]
    end
  end

  test "check_trace with opts" do
    check_trace %{timetrap: 1_000, timeout: 1_000} do
      x = 1
      tp(:debug, :oxe, %{x: x})
      {:ok, x + 3}
    after
      [
        fn _trace ->
          :ok
        end,
        fn _res, _trace ->
          :ok
        end
      ]
    end
  end

  test "tp_span" do
    check_trace do
      x = 1

      y =
        tp_span :warning, :oxe, %{y: 2} do
          x = x * 3
        end

      tp(:debug, :oxe, %{x: x + 1, y: y})
      :ok
    after
      [
        fn _trace ->
          :ok
        end,
        fn _res, _trace ->
          :ok
        end
      ]
    end
  end

  test "causality" do
    check_trace do
      tp(:cause, %{x: 1})
      tp(:consequence, %{y: 2})
    after
      [
        fn tr ->
          causality(tr, %{x: x} when x >= 1, %{y: y} when y <= 10, y >= x)

          assert_raise ExUnit.AssertionError, fn ->
            causality(tr, %{y: y} when y <= 10, %{x: x} when x >= 1, y >= x)
          end

          :ok
        end
      ]
    end
  end

  test "wait_async_action" do
    :ok = Pingado.start_trace()

    res1 =
      wait_async_action %{Pingado.kind() => x} when is_integer(x) and x > 2, 1_000 do
        tp(10, %{})
        20
      end

    res2 =
      wait_async_action %{Pingado.kind() => x} when is_integer(x) and x > 2, 1_000 do
        tp(1, %{})
        30
      end

    :ok = Pingado.stop()

    assert {20, {:ok, %{Pingado.kind() => 10}}} = res1
    assert res2 == {30, :timeout}
  end

  test "inject_crash" do
    :ok = Pingado.start_trace()

    children = [
      %{
        id: PingadoTest,
        start: {Agent, :start_link, [fn -> :state end]},
        restart: :permanent
      }
    ]

    {:ok, sup} =
      Supervisor.start_link(children,
        max_restarts: 100,
        max_seconds: 300,
        strategy: :one_for_one
      )

    [{_, pid, _, _}] = Supervisor.which_children(sup)
    ref = Process.monitor(pid)

    crash_ref =
      inject_crash(
        %{Pingado.kind() => :boom},
        Pingado.Saci.always_crash(),
        :argh
      )

    Agent.cast(pid, fn _ ->
      tp(:boom, %{})
      :never_reached
    end)

    assert_receive {:DOWN, ^ref, :process, ^pid, :argh}, 1_000

    :ok = Pingado.Saci.fix_crash(crash_ref)

    [{_, pid, _, _}] = Supervisor.which_children(sup)
    assert Agent.get(pid, & &1) == :state

    :ok = Pingado.stop()
  end
end
