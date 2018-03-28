defmodule AeutilPatriciaMerkleTreeTest do
  use ExUnit.Case

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.DB.LevelDB
  alias MerklePatriciaTree.Proof
  alias MerklePatriciaTree.DB.ExternalDB

  alias Aecore.Persistence.Worker, as: Persistence

  @tag :proof_test_success
  @tag timeout: 30_000_000
  test "Proof Success Tests" do
    {trie, list} = create_random_trie_test()
    proof = init_proof_trie()

    Enum.each(list, fn({key, value}) ->
      {^value, proof} = Proof.construct_proof({trie, key, proof})
      assert :true = Proof.verify_proof(key, value, trie.root_hash, proof.db)
    end)
  end

  def init_proof_trie() do
    put = fn(key, val) -> Rox.put(Persistence.get_db_ref(:proof), key, val) end
    get = fn(key) -> Rox.get(Persistence.get_db_ref(:proof), key) end
    Trie.new(ExternalDB.init(%{put: put, get: get}))

  end

  def create_random_trie_test() do
    put  = fn(key, val) -> Rox.put(Persistence.get_db_ref(:trie), key, val) end
    get  = fn(key) -> Rox.get(Persistence.get_db_ref(:trie), key) end
    db   = MerklePatriciaTree.Trie.new(ExternalDB.init(%{put: put, get: get }))
    list = get_random_tree_list()

    trie =
      Enum.reduce(list, db,
        fn({key, val}, acc_trie) ->
          Trie.update(acc_trie, key, val)
        end)
    {trie, list}
  end

  def get_random_tree_list(), do: for _ <- 0..10_000, do: {random_key(), "0000"}

  def random_key() do
    <<:rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4>>
  end

end