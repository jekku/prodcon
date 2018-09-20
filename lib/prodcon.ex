defmodule Prodcon do
  def start(producer_count \\ 5, consumer_count \\ 5, queue_size \\ 10) do
    queue = %{id: Queue, start: {Queue, :start_link, [%{queue_size: queue_size}]}}
    producers = Enum.map(1..producer_count, &create_producer(&1, queue))
    consumers = Enum.map(1..consumer_count, &create_consumer(&1, queue))

    Supervisor.start_link([queue] ++ producers ++ consumers, strategy: :one_for_one)
  end

  defp create_consumer(id, queue) do
    %{
      id: :"consumer_#{id}",
      start: {Consumer, :start_link, [%{id: :"consumer_#{id}", queue: Queue}]}
    }
  end

  defp create_producer(id, queue) do
    %{
      id: :"producer_#{id}",
      start: {Producer, :start_link, [%{id: :"producer_#{id}", queue: Queue}]}
    }
  end
end

defmodule Producer do
  use GenServer

  def start_link(%{id: producer_id} = args) do
    GenServer.start_link(__MODULE__, args, name: producer_id)
  end

  @impl true
  def init(%{id: id, queue: queue} = state) do
    schedule_work(id, queue)
    {:ok, state}
  end

  defp schedule_work(id, queue) do
    :rand.seed(:exs1024s)
    duration = :rand.uniform(10) * 100
    IO.puts("\t\t\t\t\t#{id}: Generating job #{duration}")
    Process.sleep(duration)

    IO.puts("\t\t\t\t\t#{id}: Sending job #{duration} to #{queue}")
    GenServer.cast(queue, {:producer, %{duration: duration, producer_id: id}})

    Process.send_after(self(), :work, 1)
  end

  def handle_info(:work, %{id: id, queue: queue} = state) do
    schedule_work(id, queue)
    {:noreply, state}
  end
end

defmodule Consumer do
  use GenServer

  def start_link(%{id: consumer_id} = args) do
    GenServer.start_link(__MODULE__, args, name: consumer_id)
  end

  def init(%{id: id, queue: queue} = state) do
    IO.puts("\t\t\t\t\t\t\t\t\t\t#{id}: Ready")
    schedule_consumption(id, queue)
    {:ok, state}
  end

  defp schedule_consumption(id, queue) do
    IO.puts("\t\t\t\t\t\t\t\t\t\t#{id}: Ready")
    GenServer.cast(queue, {:consumer, id})

    Process.send_after(self(), :work, 1)
  end

  def handle_cast(
        {:job, %{duration: duration, producer_id: producer_id}},
        %{id: id, queue: queue} = state
      ) do
    IO.puts("\t\t\t\t\t\t\t\t\t\t#{id}: Received job #{duration} from #{producer_id}")
    Process.sleep(duration)
    {:noreply, state}
  end

  def handle_info(:work, %{id: id, queue: queue} = state) do
    schedule_consumption(id, queue)
    {:noreply, state}
  end
end

defmodule Queue do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(
        %{
          queue_size: queue_size
        } = state
      ) do
    {:ok, %{jobs: [], consumers: [], queue_size: queue_size}}
  end

  def handle_cast({:consumer, consumer_id}, %{consumers: consumers, jobs: []} = state) do
    consume_job(%{state | consumers: [consumer_id | consumers]})
  end

  def handle_cast(
        {:consumer, consumer_id},
        %{consumers: consumers} = state
      ) do
    consume_job(%{state | consumers: [consumer_id | consumers]})
  end

  defp consume_job(%{jobs: []} = state) do
    {:noreply, state}
  end

  defp consume_job(
         %{
           jobs: [%{duration: duration, producer_id: producer_id} = next_job | remaining_jobs],
           consumers: [next_consumer | remaining_consumers]
         } = state
       ) do
    IO.puts("#{stats(state)} Sending job #{duration} from #{producer_id} to #{next_consumer}")
    GenServer.cast(next_consumer, {:job, next_job})
    {:noreply, %{jobs: remaining_jobs, consumers: remaining_consumers}}
  end

  def handle_cast(
        {:producer, %{duration: duration, producer_id: producer_id}},
        %{jobs: jobs, queue_size: queue_size} = state
      )
      when queue_size == length(jobs) do
    IO.puts("#{stats(state)} Discarding job #{duration} from #{producer_id}")
    {:noreply, state}
  end

  def handle_cast(
        {:producer, %{duration: duration, producer_id: producer_id} = job},
        %{jobs: []} = state
      ) do
    IO.puts("#{stats(state)} Queueing job #{duration} from #{producer_id}")
    {:noreply, %{state | jobs: [job]}}
  end

  def handle_cast(
        {:producer, %{duration: duration, producer_id: producer_id} = job},
        %{jobs: jobs, consumers: []} = state
      ) do
    IO.puts("#{stats(state)} Queueing job #{duration} from #{producer_id}")
    {:noreply, %{state | jobs: [job | jobs]}}
  end

  defp stats(%{jobs: jobs, consumers: consumers}) do
    inspect({length(jobs), length(consumers)})
  end
end
