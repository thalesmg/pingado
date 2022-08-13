defmodule Pingado.Saci do
  defdelegate always_crash(), to: :snabbkaffe_nemesis
  defdelegate recover_after(n_times), to: :snabbkaffe_nemesis
  defdelegate random_crash(crash_probability), to: :snabbkaffe_nemesis
  defdelegate periodic_crash(period, duty_cycle, phase), to: :snabbkaffe_nemesis
  defdelegate fix_crash(ref), to: :snabbkaffe_nemesis
end
