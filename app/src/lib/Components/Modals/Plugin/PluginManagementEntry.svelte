<script lang="ts">
	import { onMount } from 'svelte';
	import type { PluginMeta, PluginUpdaterConfig } from '$lib/Util/Interfaces';

	interface Props {
		pluginMeta: PluginMeta;
		isSelected: boolean;
		onSelect: () => void;
		onMetaChange: () => void;
	}

	let { pluginMeta, isSelected, onSelect, onMetaChange }: Props = $props();

	let editNameString: string | null = $state(null);
	const startRename = () => (editNameString = pluginMeta.name ?? '');
	const cancelRename = () => (editNameString = null);
	const finishRename = () => {
		if (editNameString !== null) {
			const newName = editNameString.trim() === '' ? pluginMeta.originalName : editNameString;
			if (pluginMeta.name !== newName) {
				pluginMeta.name = newName;
				onMetaChange();
			}
			cancelRename();
		}
	};
	$effect(() => {
		if (!isSelected) cancelRename();
	});

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
	ondblclick={startRename}
	class="w-full border-b border-slate-300 px-3 py-1 text-left transition-colors hover:bg-slate-100 dark:border-slate-800 dark:hover:bg-slate-800 {isSelected
		? 'bg-blue-100 dark:bg-blue-900'
		: ''}"
>
	<div class="flex select-none items-center justify-between">
		<div class="flex-1">
			{#if editNameString === null}
				<div class="font-medium">{pluginMeta.name}</div>
			{:else}
				<input
					type="text"
					class="text-black"
					bind:value={editNameString}
					onkeypress={(e) => {
						if (e && e.key === 'Enter') finishRename();
					}}
				/>
			{/if}
			{#if pluginMeta.version}
				<div class="text-sm text-slate-600 dark:text-slate-400">v{pluginMeta.version}</div>
			{/if}
		</div>
		{#if isOutdated}
			<span
				class="rounded bg-orange-500 px-2 py-1 text-xs font-semibold text-white"
				title="Update available"
			>
				Update
			</span>
		{:else if updateCheckFailed}
			<span
				class="rounded bg-red-500 px-2 py-1 text-xs font-semibold text-white"
				title="Updater URL unreachable"
			>
				Offline
			</span>
		{/if}
	</div>
</button>
