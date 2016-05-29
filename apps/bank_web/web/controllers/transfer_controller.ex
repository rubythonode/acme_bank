defmodule BankWeb.TransferController do
  use BankWeb.Web, :controller

  plug BankWeb.Authentication.Require

  def new(conn, _params) do
    transfer = BankWeb.Transfer.changeset(%BankWeb.Transfer{})
    render conn, "new.html", transfer: transfer
  end

  def create(conn, %{"transfer" => transfer_params}) do
    changeset = BankWeb.Transfer.changeset(%BankWeb.Transfer{}, transfer_params)

    if changeset.valid? do
      transfer = Ecto.Changeset.apply_changes(changeset)
      source = conn.assigns.current_customer.wallet
      destination = BankWeb.Repo.get!(BankWeb.Account, transfer.destination_account_id)
      transactions = BankWeb.Transfer.build(source, destination, "Transfer", transfer.amount_cents)

      case BankWeb.Ledger.write(transactions) do
        :ok ->
          redirect conn, to: account_path(conn, :show)
        {:error, :insufficient_funds} ->
          changeset =
            changeset
            |> Map.put(:action, :transfer)
            |> Ecto.Changeset.add_error(:amount_cents, "insufficient funds")
          render conn, "new.html", transfer: changeset
      end
    else
      changeset = %{changeset | action: :transfer}
      render conn, "new.html", transfer: changeset
    end
  end
end