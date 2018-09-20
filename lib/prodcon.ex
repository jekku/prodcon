defmodule Prodcon do
  @moduledoc """
  Documentation for Prodcon.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Prodcon.hello
      :world

  """
  def start(producer_count \\ 5, consumer_count \\ 5, queue_size \\ 10) do
    GenServer.start_link(
      Queue,
      %{
        producer_count: consumer_count,
        consumer_count: consumer_count,
        queue_size: queue_size
      },
      name: :jequeue
    )
  end
end

defmodule Producer do
  use GenServer

  @impl true
  def init(%{id: id, queue: queue} = state) do
    Task.async(fn -> schedule_work(id, queue) end)
    {:ok, state}
  end

  defp schedule_work(id, queue) do
    :rand.seed(:exs1024s)
    job = :rand.uniform(10) * 100
    IO.puts("\t\t\t\t\tPRODUCER #{id}: Generating job #{job}")
    Process.sleep(job)

    IO.puts("\t\t\t\t\tPRODUCER #{id}: Sending job #{job} to the queue")
    GenServer.cast(queue, {:producer, job, id})

    schedule_work(id, queue)
  end
end

defmodule Consumer do
  use GenServer

  def init(%{id: id, queue: queue} = state) do
    {:ok, state}
  end

  def handle_cast({:job, job, producer_id}, %{id: id, queue: queue}) do
    IO.puts("\t\t\t\t\t\t\t\t\t\tCONSUMER #{id}: Received job #{job} from #{producer_id}")
    Process.sleep(job)
  end
end

defmodule Queue do
  use GenServer

  def init(
        %{
          producer_count: producer_count,
          consumer_count: consumer_count,
          queue_size: queue_size
        } = state
      ) do
    for id <- 1..producer_count,
        do: GenServer.start_link(Producer, %{id: "producer_#{id}", queue: self()})

    for id <- 1..consumer_count,
        do: GenServer.start_link(Consumer, %{id: "consumer_#{id}", queue: self()})

    {:ok, %{jobs: [], consumers: []}}
  end

  def handle_cast({:producer, job, producer_id}, %{jobs: jobs} = state) do
    IO.puts("Queueing job #{job} from PRODUCER #{producer_id}")
    {:noreply, %{state | jobs: [job | jobs]}}
  end
end
