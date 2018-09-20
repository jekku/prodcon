defmodule Prodcon do
  def start(producer_count \\ 5, consumer_count \\ 5, queue_size \\ 10) do
    {:ok, queue} = GenServer.start_link(Queue, %{queue_size: queue_size})
    producers = Enum.map(1..producer_count, &create_producer(&1, queue))
    consumers = Enum.map(1..consumer_count, &create_consumer(&1, queue))

    Supervisor.start_link(producers ++ consumers, strategy: :one_for_one)
  end

  defp create_consumer(id, queue) do
    %{
      id: :"consumer_#{id}",
      start: {Consumer, :start_link, [%{id: id, queue: queue}]}
    }
  end

  defp create_producer(id, queue) do
    %{
      id: :"producer_#{id}",
      start: {Producer, :start_link, [%{id: id, queue: queue}]}
    }
  end
end

defmodule Producer do
  use GenServer

  def start_link(defaults) do
    GenServer.start_link(__MODULE__, defaults)
  end

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

  def start_link(defaults) do
    GenServer.start_link(__MODULE__, defaults)
  end

  def init(%{id: id, queue: queue} = state) do
    GenServer.cast(queue, {:consumer, id})
    {:ok, state}
  end

  def handle_cast({:job, job, producer_id}, %{id: id, queue: queue} = state) do
    IO.puts("\t\t\t\t\t\t\t\t\t\tCONSUMER #{id}: Received job #{job} from #{producer_id}")
    Process.send_after(queue, {:consumer, id}, job)
    {:noreply, state}
  end
end

defmodule Queue do
  use GenServer

  def init(
        %{
          queue_size: queue_size
        } = state
      ) do
    {:ok, %{jobs: [], consumers: [], queue_size: queue_size}}
  end

  def handle_cast({:consumer, consumer_id}, %{consumers: consumers, jobs: []} = state) do
    {:noreply, %{state | consumers: [consumer_id | consumers]}}
  end

  def handle_cast(
        {:consumer, consumer_id},
        %{consumers: consumers, jobs: [next_job | remaining_jobs]} = state
      ) do
    GenServer.cast(consumer_id, {:job, next_job})
    {:noreply, %{state | consumers: [consumer_id | consumers], jobs: remaining_jobs}}
  end

  def handle_cast({:producer, job, producer_id}, %{jobs: jobs, queue_size: queue_size} = state)
      when queue_size == length(jobs) do
    IO.puts("Discarding job #{job} from #{producer_id}")
    {:noreply, state}
  end

  def handle_cast({:producer, job, producer_id}, %{jobs: jobs} = state) do
    IO.puts("Queueing job #{job} from #{producer_id}")
    {:noreply, %{state | jobs: [job | jobs]}}
  end
end
