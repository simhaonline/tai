defmodule Tai.Trading.Orders.CreateFilledTest do
  use ExUnit.Case, async: false

  import Tai.TestSupport.Helpers
  alias Tai.TestSupport.Mocks

  setup do
    on_exit(fn ->
      :ok = Application.stop(:tai)
    end)

    start_supervised!(Mocks.Server)
    {:ok, _} = Application.ensure_all_started(:tai)
    :ok
  end

  @venue_order_id "df8e6bd0-a40a-42fb-8fea-b33ef4e34f14"

  test "broadcasts an event with a status of filled" do
    Tai.Events.firehose_subscribe()

    submission =
      Support.OrderSubmissions.build(Tai.Trading.OrderSubmissions.BuyLimitFok, %{
        qty: Decimal.new(10)
      })

    Mocks.Responses.Orders.FillOrKill.filled(@venue_order_id, submission)

    {:ok, %Tai.Trading.Order{}} = Tai.Trading.Orders.create(submission)

    assert_receive {Tai.Event, %Tai.Events.OrderUpdated{status: :enqueued}}
    assert_receive {Tai.Event, %Tai.Events.OrderUpdated{status: :filled} = filled_event}

    assert filled_event.venue_order_id == @venue_order_id
    assert %DateTime{} = filled_event.venue_created_at
    assert filled_event.leaves_qty == Decimal.new(0)
    assert filled_event.cumulative_qty == Decimal.new(10)
    assert filled_event.qty == Decimal.new(10)
  end

  test "fires the callback when the status changes" do
    submission =
      Support.OrderSubmissions.build(Tai.Trading.OrderSubmissions.SellLimitFok, %{
        qty: Decimal.new(10),
        order_updated_callback: fire_order_callback(self())
      })

    Mocks.Responses.Orders.FillOrKill.filled(@venue_order_id, submission)

    {:ok, _} = Tai.Trading.Orders.create(submission)

    assert_receive {
      :callback_fired,
      nil,
      %Tai.Trading.Order{side: :sell, status: :enqueued}
    }

    assert_receive {
      :callback_fired,
      %Tai.Trading.Order{side: :sell, status: :enqueued},
      %Tai.Trading.Order{side: :sell, status: :filled} = filled_order
    }

    assert filled_order.venue_order_id == @venue_order_id
    assert %DateTime{} = filled_order.venue_created_at
    assert filled_order.leaves_qty == Decimal.new(0)
    assert filled_order.cumulative_qty == Decimal.new(10)
    assert filled_order.qty == Decimal.new(10)
  end
end