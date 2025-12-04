<script lang="ts">
	import PluginEntry from './PluginEntry.svelte';
	import type { PluginMeta, PluginConfig } from '$lib/Util/Interfaces';
	import type { ClientInfo } from '$lib/Util/Store'; 

	interface Props {
		clientId: number;
		pluginList: { [key: string]: PluginMeta };
		activePlugins: ClientInfo['plugins'];
		onError: (msg: string) => void;
		onRefresh: () => void;
	}

	let { clientId, pluginList, activePlugins, onError, onRefresh }: Props = $props();

	// Map to store plugin configs
	let pluginConfigs: Map<string, PluginConfig | null> = $state(new Map());

	const getPluginConfigPromise = async (id: string, meta: PluginMeta): Promise<PluginConfig | null> => {
		if (meta.path) {
			const path = meta.path + (meta.path.endsWith('/') || meta.path.endsWith('\\') ? '' : '/') + 'bolt.json';
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
		return activePlugins.some(p => p.id === pluginId);
	};

	const getActivePluginUid = (pluginId: string): number | null => {
		const plugin = activePlugins.find(p => p.id === pluginId);
		return plugin?.uid ?? null;
	};
</script>

<div class="mx-auto w-full max-w-2xl">
	{#if Object.keys(pluginList).length === 0}
		<p class="p-4 text-center text-slate-600 dark:text-slate-400">
			No plugins installed
		</p>
	{:else}
		{#each Object.entries(pluginList).sort((a, b) => {
			const nameA = a[1].name ?? '(unnamed)';
			const nameB = b[1].name ?? '(unnamed)';
			return nameA.localeCompare(nameB);
		}) as [id, meta]}
			<PluginEntry
				pluginId={id}
				pluginMeta={meta}
				clientId={clientId}
				isActive={isPluginActive(id)}
				activePluginUid={getActivePluginUid(id)}
				mainFile={pluginConfigs.get(id)?.main ?? null}
				{onError}
				{onRefresh}
			/>
		{/each}
	{/if}
</div>
