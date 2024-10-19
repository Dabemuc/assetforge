defmodule AssetforgeWeb.PageController do
  use AssetforgeWeb, :controller

  alias AlphavantageElixirClient

  def home(conn, _params) do
    render(conn, :home, layout: false)
  end

  def fetch_data(conn, %{"symbols" => symbols}) do
    symbols_list = String.split(symbols, ",")

    results =
      symbols_list
      |> Enum.map(
        &AlphavantageElixirClient.fetch_etf_profile(
          &1,
          Application.get_env(:alpha_api, :ALPHA_VANTAGE_API_KEY)
        )
      )
      |> Enum.reduce(%{}, fn data, acc ->
        merge_data(acc, data)
      end)

    json(conn, results)
  end

  defp merge_data(acc, data) do
    acc
    |> Map.merge(data, fn key, v1, v2 ->
      case key do
        "asset_allocation" -> average_and_sort_asset_allocation(v1, v2)
        "holdings" -> average_and_sort_holdings(v1, v2)
        "sectors" -> average_and_sort_sectors(v1, v2)
        "dividend_yield" -> average_dividend_yields(v1, v2)
        "net_expense_ratio" -> average_net_expense_ratio(v1, v2)
        "portfolio_turnover" -> average_portfolio_turnover(v1, v2)
        _ -> v1
      end
    end)
  end

  defp average_and_sort_asset_allocation(allocation1, allocation2) do
    allocation1
    |> Map.merge(allocation2, fn _key, v1, v2 ->
      Decimal.div(Decimal.add(Decimal.new(v1), Decimal.new(v2)), 2)
    end)
    |> Enum.sort_by(fn {_key, value} -> Decimal.to_float(value) end, :desc)
    # Convert the list of tuples back into a map
    |> Enum.into(%{})
  end

  defp average_and_sort_holdings(holdings1, holdings2) do
    (holdings1 ++ holdings2)
    |> Enum.group_by(& &1["symbol"])
    |> Enum.map(fn {symbol, entries} ->
      %{
        "description" => List.first(entries)["description"],
        "symbol" => symbol,
        "weight" =>
          Enum.reduce(entries, Decimal.new(0), fn entry, acc ->
            Decimal.add(acc, Decimal.new(entry["weight"]))
          end)
          # Average weight
          |> Decimal.div(Decimal.new(length(entries)))
      }
    end)
    |> Enum.sort_by(&Decimal.to_float(&1["weight"]), :desc)
  end

  defp average_and_sort_sectors(sectors1, sectors2) do
    (sectors1 ++ sectors2)
    |> Enum.group_by(& &1["sector"])
    |> Enum.map(fn {sector, entries} ->
      %{
        "sector" => sector,
        "weight" =>
          Enum.reduce(entries, Decimal.new(0), fn entry, acc ->
            Decimal.add(acc, Decimal.new(entry["weight"]))
          end)
          # Average weight
          |> Decimal.div(Decimal.new(length(entries)))
      }
    end)
    |> Enum.sort_by(&Decimal.to_float(&1["weight"]), :desc)
  end

  defp average_dividend_yields(yield1, yield2) do
    Decimal.div(Decimal.add(Decimal.new(yield1), Decimal.new(yield2)), 2)
  end

  defp average_net_expense_ratio(ratio1, ratio2) do
    Decimal.div(Decimal.add(Decimal.new(ratio1), Decimal.new(ratio2)), 2)
  end

  defp average_portfolio_turnover(turnover1, turnover2) do
    Decimal.div(Decimal.add(Decimal.new(turnover1), Decimal.new(turnover2)), 2)
  end
end
