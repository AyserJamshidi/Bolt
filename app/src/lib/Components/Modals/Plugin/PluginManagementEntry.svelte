<script lang="ts">
	import { onMount } from 'svelte';
	import type { PluginMeta, PluginUpdaterConfig } from '$lib/Util/Interfaces';

	interface Props {
    pluginId: string;
		pluginMeta: PluginMeta;
		isSelected: boolean;
		onSelect: () => void;
	}

	let { pluginId, pluginMeta, isSelected, onSelect }: Props = $props();

	let isOutdated: boolean = $state(false);
	let checkingUpdate: boolean = $state(false);
	let updateCheckFailed: boolean = $state(false);

	// Check if plugin has an update available
	const checkForUpdate = async () => {
		if (!pluginMeta.updaterURL || checkingUpdate) return;
		
		checkingUpdate = true;
		updateCheckFailed = false;
		try {
			const response = await fetch(pluginMeta.updaterURL);
			if (!response.ok) {
				updateCheckFailed = true;
				return;
			}
			
			const config: PluginUpdaterConfig = await response.json();
			
			if (config.sha256 && pluginMeta.sha256) {
				isOutdated = config.sha256 !== pluginMeta.sha256;
			} else if (config.version && pluginMeta.version) {
				isOutdated = config.version !== pluginMeta.version;
			}
		} catch (e) {
			updateCheckFailed = true;
		} finally {
			checkingUpdate = false;
		}
	};

	// Check on mount if there's an updater URL
	onMount(() => {
		if (pluginMeta.updaterURL) {
			checkForUpdate();
		}
	});
</script>

<button
	onclick={onSelect}
	class="w-full border-b border-slate-300 p-3 text-left transition-colors hover:bg-slate-100 dark:border-slate-800 dark:hover:bg-slate-800 {isSelected ? 'bg-blue-100 dark:bg-blue-900' : ''}"
>
	<div class="flex items-center justify-between">
		<div class="flex-1">
			<div class="font-medium">{pluginMeta.name}</div>
			{#if pluginMeta.version}
				<div class="text-sm text-slate-600 dark:text-slate-400">v{pluginMeta.version}</div>
			{/if}
		</div>
		{#if isOutdated}
			<span class="rounded bg-orange-500 px-2 py-1 text-xs font-semibold text-white" title="Update available">
				Update
			</span>
		{:else if updateCheckFailed}
			<span class="rounded bg-red-500 px-2 py-1 text-xs font-semibold text-white" title="Updater URL unreachable">
				Offline
			</span>
		{/if}
	</div>
</button>
