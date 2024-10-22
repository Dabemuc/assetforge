defmodule AssetforgeWeb.PageController do
  use AssetforgeWeb, :controller

  alias AlphavantageElixirClient
  alias Decimal

  def home(conn, _params) do
    render(conn, :home, layout: false)
  end

  def fetch_data(conn, %{"symbols" => symbols, "percentages" => percentages}) do
    # Debug: Log the received symbols and percentages
    IO.inspect(symbols, label: "Received Symbols")
    IO.inspect(percentages, label: "Received Percentages")

    # Validate symbols and percentages
    with :ok <- validate_symbols(symbols),
         {:ok, percentages} <- validate_and_convert_percentages(percentages) do
      # Fetch the ETF profiles
      etf_profiles =
        symbols
        |> Enum.map(fn symbol ->
          AlphavantageElixirClient.fetch_etf_profile(
            symbol,
            Application.get_env(:alpha_api, :ALPHA_VANTAGE_API_KEY)
          )
        end)

      IO.inspect(percentages, label: "Received Percentages after validate")

      # Multiply fetched data by percentages
      etf_profiles_with_percentages =
        Enum.zip(etf_profiles, percentages)
        |> Enum.map(fn {etf_profile, percentage} ->
          apply_percentage_to_etf_data(etf_profile, percentage)
        end)

      # Merge the fetched data
      results =
        etf_profiles_with_percentages
        |> Enum.reduce(%{}, fn data, acc ->
          merge_data(acc, data)
        end)

      json(conn, results)
    else
      {:error, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})
    end
  end

  # Validate symbols
  defp validate_symbols(symbols) do
    if Enum.all?(symbols, &valid_symbol?/1) do
      :ok
    else
      {:error, "Invalid symbols format. Symbols must be non-empty strings."}
    end
  end

  # Helper to check if a symbol is valid (non-empty string)
  defp valid_symbol?(symbol) when is_binary(symbol) and byte_size(symbol) > 0, do: true
  defp valid_symbol?(_), do: false

  # Validate and convert percentages to Decimal
  defp validate_and_convert_percentages(percentages) do
    percentages
    |> Enum.map(&convert_to_decimal/1)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, decimal}, {:ok, acc} -> {:cont, {:ok, acc ++ [decimal]}}
      {:error, percentage}, _ -> {:halt, {:error, "Invalid percentage format: #{percentage}"}}
    end)
  end

  # Convert percentage to Decimal or return an error
  defp convert_to_decimal(percentage) do
    case Decimal.parse(percentage) do
      # Ensure no remainder after parsing
      {decimal, ""} -> {:ok, decimal}
      # If there is a remainder, it's invalid
      {_, _} -> {:error, percentage}
      :error -> {:error, percentage}
    end
  end

  # Merge data logic remains the same
  defp merge_data(acc, data) do
    acc
    |> Map.merge(data, fn key, v1, v2 ->
      case key do
        "asset_allocation" -> merge_and_sort_asset_allocation(v1, v2)
        "holdings" -> merge_and_sort_holdings(v1, v2)
        "sectors" -> merge_and_sort_sectors(v1, v2)
        "dividend_yield" -> merge_dividend_yields(v1, v2)
        "net_expense_ratio" -> merge_net_expense_ratio(v1, v2)
        "portfolio_turnover" -> merge_portfolio_turnover(v1, v2)
        _ -> v1
      end
    end)
  end

  defp merge_and_sort_asset_allocation(allocation1, allocation2) do
    allocation1
    |> Map.merge(allocation2, fn _key, v1, v2 ->
      Decimal.add(Decimal.new(v1), Decimal.new(v2))
    end)
    |> Enum.sort_by(fn {_key, value} -> Decimal.to_float(value) end, :desc)
    |> Enum.into(%{})
  end

  defp merge_and_sort_holdings(holdings1, holdings2) do
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
      }
    end)
    |> Enum.sort_by(&Decimal.to_float(&1["weight"]), :desc)
  end

  defp merge_and_sort_sectors(sectors1, sectors2) do
    (sectors1 ++ sectors2)
    |> Enum.group_by(& &1["sector"])
    |> Enum.map(fn {sector, entries} ->
      %{
        "sector" => sector,
        "weight" =>
          Enum.reduce(entries, Decimal.new(0), fn entry, acc ->
            Decimal.add(acc, Decimal.new(entry["weight"]))
          end)
      }
    end)
    |> Enum.sort_by(&Decimal.to_float(&1["weight"]), :desc)
  end

  defp merge_dividend_yields(yield1, yield2) do
    Decimal.add(Decimal.new(yield1), Decimal.new(yield2))
  end

  defp merge_net_expense_ratio(ratio1, ratio2) do
    Decimal.add(Decimal.new(ratio1), Decimal.new(ratio2))
  end

  defp merge_portfolio_turnover(turnover1, turnover2) do
    Decimal.add(Decimal.new(turnover1), Decimal.new(turnover2))
  end

  defp apply_percentage_to_etf_data(etf_profile, percentage_decimal) do
    # Update asset allocation
    asset_allocation =
      Enum.map(etf_profile["asset_allocation"], fn {asset_type, weight} ->
        {asset_type, Decimal.mult(Decimal.new(weight), percentage_decimal)}
      end)
      |> Enum.into(%{})

    # Update holdings weights
    holdings =
      Enum.map(etf_profile["holdings"], fn holding ->
        Map.update!(holding, "weight", fn weight ->
          Decimal.mult(Decimal.new(weight), percentage_decimal)
        end)
      end)

    # Update sector weights
    sectors =
      Enum.map(etf_profile["sectors"], fn sector ->
        Map.update!(sector, "weight", fn weight ->
          Decimal.mult(Decimal.new(weight), percentage_decimal)
        end)
      end)

    # Update dividend yield
    dividend_yield =
      Decimal.div(
        Decimal.mult(Decimal.new(etf_profile["dividend_yield"]), percentage_decimal),
        100
      )

    # Update net expense ratio
    net_expense_ratio =
      Decimal.div(
        Decimal.mult(Decimal.new(etf_profile["net_expense_ratio"]), percentage_decimal),
        100
      )

    # Update portfolio turnover
    portfolio_turnover =
      Decimal.div(
        Decimal.mult(Decimal.new(etf_profile["portfolio_turnover"]), percentage_decimal),
        100
      )

    # Return the updated ETF profile
    Map.put(etf_profile, "asset_allocation", asset_allocation)
    |> Map.put("holdings", holdings)
    |> Map.put("sectors", sectors)
    |> Map.put("dividend_yield", dividend_yield)
    |> Map.put("net_expense_ratio", net_expense_ratio)
    |> Map.put("portfolio_turnover", portfolio_turnover)
  end
end
