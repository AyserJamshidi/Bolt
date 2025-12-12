<script lang="ts">
	import PluginEntry from './PluginEntry.svelte';
	import type { PluginMeta, PluginConfig } from '$lib/Util/Interfaces';
	import type { ClientInfo } from '$lib/Util/Store';
	import { GlobalState } from '$lib/State/GlobalState';
	import { bolt } from '$lib/State/Bolt';
	import { BoltService } from '$lib/Services/BoltService';

	interface Props {
		clientId: number;
		accountID?: string;
		pluginList: { [key: string]: PluginMeta };
		activePlugins: ClientInfo['plugins'];
		startPlugin: (clientId: number, pluginId: string, path: string | null, main: string) => void;
		onError: (msg: string) => void;
		onRefresh: () => void;
	}

	let { clientId, accountID, pluginList, activePlugins, startPlugin, onError, onRefresh }: Props =
		$props();

	let autostart = $state(bolt.autostart ?? {});

	const isPluginAutostart = (pluginId: string): boolean => {
		if (!accountID || !autostart) return false;
		return autostart[accountID]?.includes(pluginId) ?? false;
	};

	// Map to store plugin configs
	let pluginConfigs: Map<string, PluginConfig | null> = $state(new Map());

	const getPluginConfigPromise = async (
		id: string,
		meta: PluginMeta
	): Promise<PluginConfig | null> => {
		if (meta.path) {
			const path =
				meta.path + (meta.path.endsWith('/') || meta.path.endsWith('\\') ? '' : '/') + 'bolt.json';
			const response = await fetch('/read-json-file?' + new URLSearchParams({ path }).toString());
			if (!response.ok) return null;
			return response.json();
		} else {
			const response = await fetch('/get-plugindir-json?' + new URLSearchParams({ id }).toString());
			if (!response.ok) return null;
			return response.json();
		}
	};

	// Load all plugin configs
	$effect(() => {
		Object.entries(pluginList).forEach(async ([id, meta]) => {
			const config = await getPluginConfigPromise(id, meta);
			pluginConfigs.set(id, config);
			pluginConfigs = pluginConfigs; // trigger reactivity
		});
	});

	const isPluginActive = (pluginId: string): boolean => {
		return activePlugins.some((p) => p.id === pluginId);
	};

	const getActivePluginUid = (pluginId: string): number | null => {
		const plugin = activePlugins.find((p) => p.id === pluginId);
		console.log('Getting UID for', pluginId, 'found:', plugin);
		return plugin?.uid ?? null;
	};

	const handleAutostartChange = (pluginId: string, enabled: boolean) => {
		if (!accountID) return;

		if (enabled) {
			if (!autostart[accountID]) {
				autostart[accountID] = [];
			}
			if (!autostart[accountID].includes(pluginId)) {
				autostart[accountID].push(pluginId);
			}
		} else {
			if (autostart[accountID]) {
				const index = autostart[accountID].indexOf(pluginId);
				if (index !== -1) {
					autostart[accountID].splice(index, 1);
					if (autostart[accountID].length === 0) {
						delete autostart[accountID];
					}
				}
			}
		}

		// Sync back and save
		bolt.autostart = autostart;
		autostart = autostart; // trigger Svelte reactivity
		BoltService.savePluginConfig();
		GlobalState.pluginConfigHasPendingChanges = true;
	};
</script>

<div class="mx-auto w-full max-w-2xl">
	{#if Object.keys(pluginList).length === 0}
		<p class="p-4 text-center text-slate-600 dark:text-slate-400">No plugins installed</p>
	{:else}
		{#each Object.entries(pluginList).sort((a, b) => {
			const nameA = a[1].name ?? '(unnamed)';
			const nameB = b[1].name ?? '(unnamed)';
			return nameA.localeCompare(nameB);
		}) as [id, meta]}
			<PluginEntry
				pluginId={id}
				pluginMeta={meta}
				{clientId}
				clientIdentity={accountID}
				isActive={isPluginActive(id)}
				isAutostart={isPluginAutostart(id)}
				activePluginUid={getActivePluginUid(id)}
				{startPlugin}
				mainFile={pluginConfigs.get(id)?.main ?? null}
				{onError}
				{onRefresh}
				onAutostartChange={handleAutostartChange}
			/>
		{/each}
	{/if}
</div>
