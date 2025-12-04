<script lang="ts">
	import PluginManagementEntry from './PluginManagementEntry.svelte';
	import type { PluginMeta } from '$lib/Util/Interfaces';

	interface Props {
		pluginList: { [key: string]: PluginMeta };
		selectedPluginId: string | null;
		onSelectPlugin: (id: string) => void;
	}

	let { pluginList, selectedPluginId, onSelectPlugin }: Props = $props();
</script>

<div class="h-full overflow-y-auto border-r-2 border-slate-300 dark:border-slate-800">
	{#if Object.keys(pluginList).length === 0}
		<p class="p-4 text-center text-sm text-slate-600 dark:text-slate-400">
			No plugins installed
		</p>
	{:else}
		{#each Object.entries(pluginList).sort((a, b) => {
			const nameA = a[1].name ?? '(unnamed)';
			const nameB = b[1].name ?? '(unnamed)';
			return nameA.localeCompare(nameB);
		}) as [id, meta] (id)}
			<PluginManagementEntry
        pluginId={id}
				pluginMeta={meta}
				isSelected={selectedPluginId === id}
				onSelect={() => onSelectPlugin(id)}
			/>
		{/each}
	{/if}
</div>
