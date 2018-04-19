defmodule Aecore.Oracle.OracleStateTree do
  @moduledoc """
  Top level oracle state tree.
  """
  alias Aecore.Oracle.Oracle
  alias Aecore.Wallet.Worker, as: Wallet
  alias Aeutil.Serialization

  @type encoded_oracle_state :: binary()

  # abstract datatype representing a merkle tree
  @type tree :: tuple()
  @type oracle_state :: tree()
  @type hash :: binary()

  @spec init_empty() :: tree()
  def init_empty do
    %{registered_oracles: %{}, interaction_objects: %{}}
  end

  def init_empty1 do
    empty_tree = :gb_merkle_trees.empty()

    Enum.reduce(init_oracle_keys(), empty_tree, fn oracle_key, acc_tree ->
      :gb_merkle_trees.enter(oracle_key, <<>>, acc_tree)
    end)
  end

  defp init_oracle_keys do
    [
      Oracle.encoded_registered_oracles(),
      Oracle.encoded_interaction_objects()
    ]
  end

  # def put_registered_oracles(tree, oracle) do

  # end

  # def put_interaction_objects(tree, object) do

  # end

  @spec get(tree(), Wallet.pubkey()) :: Account.t()
  def get(tree, key) do
    :gb_merkle_trees.lookup(key, tree)
  end

  # def has_key?(tree, key) do
  #   :gb_merkle_trees.lookup(key, tree) != :none
  # end

  # @spec delete(tree(), Wallet.pubkey()) :: tree()
  # def delete(tree, key) do
  #   :gb_merkle_trees.delete(key, tree)
  # end

  @spec balance(tree()) :: tree()
  def balance(tree) do
    :gb_merkle_trees.balance(tree)
  end

  @spec root_hash(tree()) :: hash()
  def root_hash(tree) do
    :gb_merkle_trees.root_hash(tree)
  end

  @spec reduce(tree(), any(), fun()) :: any()
  def reduce(tree, acc, fun) do
    :gb_merkle_trees.foldr(fun, acc, tree)
  end

  @spec size(tree()) :: non_neg_integer()
  def size(tree) do
    :gb_merkle_trees.size(tree)
  end
end
