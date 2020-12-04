defmodule Vaporator.EctoMigrator do
  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :migrate, []},
      type: :worker,
      restart: :transient,
      shutdown: 500
    }
  end

  @doc "Replacement for Mix.Tasks.Ecto.Migrate"
  def migrate do
    repos = Application.get_env(:vaporator, :ecto_repos)
    for repo <- repos, do: migrate(repo)
    :ignore
  end

  def migrate(Vaporator.Repo) do
    migrate(
      Vaporator.Repo,
      migration_directory()
    )
  end

  def migrate(repo, migrations_path) do
    opts = [all: true]
    {:ok, pid, apps} = Mix.Ecto.ensure_started(repo, opts)

    migrator = &Ecto.Migrator.run/4
    migrated = migrator.(repo, migrations_path, :up, opts)
    pid && repo.stop(pid)
    restart_apps_if_migrated(apps, migrated)
    Process.sleep(500)
  end

  defp migration_directory do
    Path.join([:code.priv_dir(:vaporator), "repo", "migrations"])
  end

  # Pulled this out of Ecto because Ecto's version
  # messes with Logger config
  def restart_apps_if_migrated(_, []), do: :ok

  def restart_apps_if_migrated(apps, [_ | _]) do
    for app <- Enum.reverse(apps) do
      Application.stop(app)
    end

    for app <- apps do
      Application.ensure_all_started(app)
    end

    :ok
  end

  @doc "Replacement for Mix.Tasks.Ecto.Drop"
  def drop do
    repos = Application.get_env(:vaporator, :ecto_repos)

    for repo <- repos do
      case drop(repo) do
        :ok -> :ok
        {:error, :already_down} -> :ok
        {:error, reason} -> raise reason
      end
    end
  end

  def drop(repo) do
    repo.__adapter__.storage_down(repo.config)
  end
end
