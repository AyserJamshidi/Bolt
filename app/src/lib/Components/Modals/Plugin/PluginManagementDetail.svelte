<script lang="ts">
	import type { PluginMeta, PluginConfig, PluginUpdaterConfig } from '$lib/Util/Interfaces';
	import { GlobalState } from '$lib/State/GlobalState';

	interface Props {
		pluginId: string;
		pluginMeta: PluginMeta;
		pluginConfig: PluginConfig | null;
		onRemove: () => void;
		onUpdate: () => void;
		setMessageInfo: (msg: string) => void;
		setMessageError: (msg: string) => void;
	}

	let {
		pluginId,
		pluginMeta,
		pluginConfig,
		onRemove,
		onUpdate,
		setMessageInfo,
		setMessageError
	}: Props = $props();

	const browseData = () => {
		if (pluginMeta.path) {
			fetch('/browse-directory?' + new URLSearchParams({ path: pluginMeta.path }).toString());
		} else {
			fetch('/browse-plugin-data?' + new URLSearchParams({ id: pluginId }).toString());
		}
	};

	const browseConfig = () => {
		fetch('/browse-plugin-config?' + new URLSearchParams({ id: pluginId }).toString());
	};

	const updatePlugin = async () => {
		if (!pluginMeta.updaterURL) return;

		const url = pluginMeta.updaterURL;
		const x = await fetch(url);
		if (!x.ok) {
			setMessageError(`can't update plugin: updater URL returned ${x.status}: ${x.statusText}`);
			return;
		}

		let config: PluginUpdaterConfig = await x.json();
		if (!config.url) {
			setMessageInfo(
				`can't update plugin '${pluginMeta.name}': no remote download URL is configured`
			);
			return;
		}

		let downloadNeeded = false;
		if (config.sha256) {
			if (pluginMeta.sha256 !== config.sha256) {
				downloadNeeded = true;
			}
		} else if (config.version) {
			if (pluginMeta.version !== config.version) {
				downloadNeeded = true;
			}
		}

		if (!downloadNeeded) {
			setMessageInfo(`plugin '${pluginMeta.name}' is already up-to-date`);
			return;
		}

		const r = await fetch(config.url);
		if (!r.ok) {
			setMessageError(
				`can't update plugin: remote download URL returned ${r.status}: ${r.statusText}`
			);
			return;
		}
		const data = await r.arrayBuffer();
		if (config.sha256) {
			const hash = await crypto.subtle.digest('SHA-256', data);
			const hashStr = Array.from(new Uint8Array(hash))
				.map((x) => x.toString(16).padStart(2, '0'))
				.join('');
			if (config.sha256 !== hashStr) {
				setMessageError(`can't update plugin '${pluginMeta.name}': incorrect file hash`);
				return;
			}
		}
		await fetch('/install-plugin?' + new URLSearchParams({ id: pluginId }).toString(), {
			method: 'POST',
			body: data
		});

		GlobalState.pluginConfigHasPendingChanges = true;
		setMessageInfo(`plugin '${pluginMeta.name}' updated`);
		onUpdate();
	};

	const removePlugin = async () => {
		await fetch(
			'/uninstall-plugin?' +
				new URLSearchParams({
					id: pluginId,
					delete_data_dir: typeof pluginMeta.path === 'string' ? '0' : '1'
				}).toString()
		);
		GlobalState.pluginConfigHasPendingChanges = true;
		setMessageInfo(`plugin '${pluginMeta.name}' uninstalled`);
		onRemove();
	};
</script>

{#if pluginConfig}
	<div class="flex h-full flex-col items-center justify-center p-6 text-center">
		<h2 class="pb-2 text-2xl font-bold">
			{pluginConfig.name ?? '(unnamed)'}
		</h2>
		{#if pluginConfig.version}
			<p class="pb-4 text-lg italic text-slate-600 dark:text-slate-400">
				v{pluginConfig.version}
			</p>
		{/if}
		<p class="pb-6 {pluginConfig.description ? '' : 'italic text-slate-500'}">
			{pluginConfig.description ?? 'no description'}
		</p>

		<div class="flex flex-col items-center justify-center gap-2">
			<div class="flex flex-wrap justify-center gap-2">
				<button
					class="rounded-lg bg-blue-500 px-4 py-2 font-bold text-black duration-200 hover:opacity-75"
					onclick={browseData}
				>
					Browse data
				</button>

				<button
					class="rounded-lg bg-blue-500 px-4 py-2 font-bold text-black duration-200 hover:opacity-75"
					onclick={browseConfig}
				>
					Browse config
				</button>

				{#if pluginMeta.updaterURL}
					<button
						class="rounded-lg bg-blue-500 px-4 py-2 font-bold text-black duration-200 hover:opacity-75"
						onclick={updatePlugin}
					>
						Check updates
					</button>
				{/if}
			</div>

			<button
				class="rounded-lg bg-rose-500 px-4 py-2 font-bold text-black duration-200 hover:opacity-75"
				onclick={removePlugin}
			>
				Remove
			</button>
		</div>
	</div>
{:else}
	<div class="flex h-full items-center justify-center p-6">
		<p class="text-slate-600 dark:text-slate-400">Loading plugin details...</p>
	</div>
{/if}
