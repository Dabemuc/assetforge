defmodule AssetforgeWeb.PageController do
  use AssetforgeWeb, :controller

  alias AlphavantageElixirClient

  def home(conn, _params) do
    # Initial data fetch for a default symbol
    data = AlphavantageElixirClient.fetch_etf_profile("QQQ", "demo")
    render(conn, :home, layout: false, data: data)
  end

  def fetch_data(conn, %{"symbols" => symbols}) do
    symbols_list = String.split(symbols, ",")

    results =
      symbols_list
      |> Enum.map(&AlphavantageElixirClient.fetch_etf_profile(&1, "demo"))
      |> Enum.reduce(%{}, fn data, acc ->
        merge_data(acc, data)
      end)

    json(conn, results)
  end

  defp merge_data(acc, data) do
    acc
    |> Map.merge(data, fn key, v1, v2 ->
      case key do
        "asset_allocation" -> merge_asset_allocation(v1, v2)
        "holdings" -> merge_holdings(v1, v2)
        "sectors" -> merge_sectors(v1, v2)
        "dividend_yield" -> sum_dividend_yields(v1, v2)
        # Ignore keys not specified for merging
        _ -> v1
      end
    end)
  end

  defp merge_asset_allocation(allocation1, allocation2) do
    Map.merge(allocation1, allocation2, fn _key, v1, v2 ->
      Decimal.add(Decimal.new(v1), Decimal.new(v2))
    end)
  end

  defp merge_holdings(holdings1, holdings2) do
    (holdings1 ++ holdings2)
    # Use string key "symbol"
    |> Enum.group_by(& &1["symbol"])
    |> Enum.map(fn {symbol, entries} ->
      %{
        "description" => List.first(entries)["description"],
        "symbol" => symbol,
        "weight" =>
          Enum.reduce(entries, Decimal.new(0), fn entry, acc ->
            # Use string key "weight"
            Decimal.add(acc, Decimal.new(entry["weight"]))
          end)
      }
    end)
  end

  defp merge_sectors(sectors1, sectors2) do
    (sectors1 ++ sectors2)
    # Use string key "sector"
    |> Enum.group_by(& &1["sector"])
    |> Enum.map(fn {sector, entries} ->
      %{
        "sector" => sector,
        "weight" =>
          Enum.reduce(entries, Decimal.new(0), fn entry, acc ->
            # Use string key "weight"
            Decimal.add(acc, Decimal.new(entry["weight"]))
          end)
      }
    end)
  end

  defp sum_dividend_yields(yield1, yield2) do
    Decimal.add(Decimal.new(yield1), Decimal.new(yield2))
  end
end
