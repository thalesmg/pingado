defmodule Pingado.Saci do
  defdelegate always_crash(), to: :snabbkaffe_nemesis
  defdelegate fix_crash(ref), to: :snabbkaffe_nemesis
end
