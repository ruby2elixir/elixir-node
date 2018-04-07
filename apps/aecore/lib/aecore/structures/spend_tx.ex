defmodule Aecore.Structures.SpendTx do
  @moduledoc """
  Aecore structure of a transaction data.
  """

  @behaviour Aecore.Structures.Transaction
  alias Aecore.Structures.SpendTx
  alias Aecore.Structures.Account
  alias Aecore.Chain.ChainState
  alias Aecore.Wallet
  alias Aecore.Structures.Account
  alias Aecore.Txs.Pool.Worker, as: Pool

  require Logger

  @typedoc "Expected structure for the Spend Transaction"
  @type payload :: %{
          receiver: Wallet.pubkey(),
          amount: non_neg_integer(),
          version: non_neg_integer()
        }

  @typedoc "Reason for the error"
  @type reason :: String.t()

  @typedoc "Structure that holds specific transaction info in the chainstate.
  In the case of SpendTx we don't have a subdomain chainstate."
  @type tx_type_state() :: %{}

  @typedoc "Structure of the Spend Transaction type"
  @type t :: %SpendTx{
          receiver: Wallet.pubkey(),
          amount: non_neg_integer(),
          version: non_neg_integer()
        }

  @doc """
  Definition of Aecore SpendTx structure

  ## Parameters
  - receiver: To account is the public address of the account receiving the transaction
  - amount: The amount of tokens send through the transaction
  - version: States whats the version of the Spend Transaction
  """
  defstruct [:receiver, :amount, :version]
  use ExConstructor

  # Callbacks
  
  @callback get_chain_state_name() :: atom() | nil
  def get_chain_state_name() do nil end
  
  @spec init(payload()) :: SpendTx.t()
  def init(%{receiver: receiver, amount: amount}) do
    %SpendTx{receiver: receiver, amount: amount, version: get_tx_version()}
  end

  @doc """
  Checks wether the amount that is send is not a negative number
  """
  @spec is_valid?(SpendTx.t(), SignedTx.t()) :: boolean()
  def is_valid?(%SpendTx{} = tx, signed_tx) do
    senders = signed_tx |> SignedTx.data_tx() |> DataTx.senders()

    cond do
      tx.amount < 0 ->
        Logger.error("The amount cannot be a negative number")
        false

      tx.version != get_tx_version() ->
        Logger.error("Invalid version")
        false

      length(senders) != 1 ->
        Logger.error("Invalid senders number")
        false

      true ->
        true
    end
  end

  @doc """
  Makes a rewarding SpendTx (coinbase tx) for the miner that mined the next block
  """
  @spec reward(SpendTx.t(), non_neg_integer(), ChainState.account()) :: ChainState.accounts()
  def reward(%SpendTx{} = tx, _block_height, account_state) do
    Account.transaction_in(account_state, tx.amount)
  end

  @doc """
  Changes the account state (balance) of the sender and receiver.
  """
  @spec process_chainstate!(
          ChainState.account(),
          tx_type_state(),
          non_neg_integer(),
          SpendTx.t(),
          SignedTx.t()
        ) :: {ChainState.accounts(), tx_type_state()}
  def process_chainstate!(accounts, %{}, _block_height, %SpendTx{} = tx, signed_tx) do
    sender = signed_tx |> SignedTx.data_tx() |> DataTx.sender()

    new_accounts =
      accounts
      |> Map.update(sender, Account.empty(), fn acc ->
        Account.transaction_in(acc, tx.amount * -1)
      end)
      |> Map.update(tx.receiver, Account.empty(), fn acc ->
        Account.transaction_in(acc, tx.amount)
      end)

    {new_accounts, %{}}
  end

  @doc """
  Checks whether all the data is valid according to the SpendTx requirements,
  before the transaction is executed.
  """
  @spec preprocess_check!(
    ChainState.accounts(),
    tx_type_state(),
    non_neg_integer(),
    SpendTx.t(),
    SignedTx.t()
  ) :: :ok
  def preprocess_check!(accounts, %{}, _block_height, tx, signed_tx) do
    data_tx = SignedTx.data_tx(signed_tx)
    sender_state = Map.get(accounts, DataTx.sender(data_tx), Account.empty())
    
    cond do
      sender_state.balance - (DataTx.fee(data_tx) + tx.amount) < 0 ->
        throw({:error, "Negative balance"})

      true ->
        :ok
    end
  end

  @spec deduct_fee(ChainState.accounts(), SpendTx.t(), SignedTx.t(), non_neg_integer()) :: ChainState.account()
  def deduct_fee(accounts, _tx, signed_tx, fee) do
    DataTx.standard_deduct_fee(accounts, signed_tx, fee)
  end

  @spec is_minimum_fee_met?(SignedTx.t(), :miner | :pool | :validation) :: boolean()
  def is_minimum_fee_met?(tx, identifier) do
    if identifier == :validation do
      true
    else
      tx_size_bytes = Pool.get_tx_size_bytes(tx)

      bytes_per_token =
        case identifier do
          :pool ->
            Application.get_env(:aecore, :tx_data)[:pool_fee_bytes_per_token]

          :miner ->
            Application.get_env(:aecore, :tx_data)[:miner_fee_bytes_per_token]
        end

      tx.data.fee >= Float.floor(tx_size_bytes / bytes_per_token)
    end
  end

  def get_tx_version, do: Application.get_env(:aecore, :spend_tx)[:version]
end
