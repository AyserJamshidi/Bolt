<script lang="ts">
	import type { PluginConfig, PluginMeta, PluginUpdaterConfig } from '$lib/Util/Interfaces';
	import { GlobalState } from '$lib/State/GlobalState';

	interface Props {
		hasLibArchive: boolean;
		pluginList: { [key: string]: PluginMeta };
		onInstallFromURL: (url: string) => Promise<void>;
		jsonFilePicker: (cb: () => void) => void;
		getPluginConfigPromiseFromDataDir: (id: string) => Promise<PluginConfig | null>;
		setMessageInfo: (msg: string) => void;
		setMessageError: (msg: string) => void;
	}

	let {
		hasLibArchive,
		pluginList,
		onInstallFromURL,
		jsonFilePicker,
		getPluginConfigPromiseFromDataDir,
		setMessageInfo,
		setMessageError
	}: Props = $props();

	let showURLEntry: boolean = $state(false);
	let textURLEntry: string = $state('');
	let disableButtons: boolean = $state(false);

	const handleInstallFromURL = async () => {
		if (!textURLEntry) return;
		disableButtons = true;
		try {
			await onInstallFromURL(textURLEntry);
			showURLEntry = false;
			textURLEntry = '';
		} finally {
			disableButtons = false;
		}
	};

	const updatePluginById = async (id: string, meta: PluginMeta): Promise<boolean> => {
		if (!meta.updaterURL) return false;

		const url = meta.updaterURL;
		const x = await fetch(url);
		if (!x.ok) return false;

		let config: PluginUpdaterConfig = await x.json();
		if (!config.url) return false;

		let downloadNeeded = false;
		if (config.sha256) {
			if (meta.sha256 !== config.sha256) downloadNeeded = true;
		} else if (config.version) {
			if (meta.version !== config.version) downloadNeeded = true;
		}

		if (!downloadNeeded) return false;

		const r = await fetch(config.url);
		if (!r.ok) return false;

		const data = await r.arrayBuffer();
		if (config.sha256) {
			const hash = await crypto.subtle.digest('SHA-256', data);
			const hashStr = Array.from(new Uint8Array(hash))
				.map((x) => x.toString(16).padStart(2, '0'))
				.join('');
			if (config.sha256 !== hashStr) return false;
		}

		await fetch('/install-plugin?' + new URLSearchParams({ id }).toString(), {
			method: 'POST',
			body: data
		});

		const plugin = await getPluginConfigPromiseFromDataDir(id);
		if (!plugin) return false;

		if (config.sha256) meta.sha256 = config.sha256;
		if (plugin.name) meta.name = plugin.name;
		if (plugin.version) meta.version = plugin.version;

		GlobalState.pluginConfigHasPendingChanges = true;
		return true;
	};

	const updateAllPlugins = async () => {
		disableButtons = true;
		let updatedCount = 0;
		let skippedCount = 0;

		try {
			for (const [id, meta] of Object.entries(pluginList)) {
				if (!meta.updaterURL) {
					skippedCount++;
					continue;
				}

				const result = await updatePluginById(id, meta);
				if (result) updatedCount++;
			}

			if (updatedCount > 0) {
				setMessageInfo(
					`Updated ${updatedCount} plugin(s). ${skippedCount} skipped (no updater URL).`
				);
			} else {
				setMessageInfo(
					`All plugins are up-to-date. ${skippedCount} plugin(s) have no updater URL.`
				);
			}
		} catch (e) {
			setMessageError(`Error updating plugins: ${e}`);
		} finally {
			disableButtons = false;
		}
	};

	const onInstallFromFolder = () => {
		disableButtons = true;
		jsonFilePicker(() => (disableButtons = false));
	};
</script>

<div class="border-b border-slate-300 pb-4 dark:border-slate-800">
	<h3 class="mb-3 text-lg font-semibold">Install Plugin</h3>
	<div class="flex justify-center gap-4">
		<button
			class="flex flex-col items-center gap-2 rounded-lg bg-blue-500 px-6 py-3 duration-200 enabled:hover:opacity-75 disabled:bg-gray-500"
			onclick={() => {
				showURLEntry = !showURLEntry;
				textURLEntry = '';
			}}
			disabled={!hasLibArchive || disableButtons}
			title="Install plugin from updater URL"
		>
			<img src="svgs/download-solid.svg" alt="" class="h-6 w-6" />
			<span class="text-sm font-medium text-black">From URL</span>
		</button>
		<button
			class="flex flex-col items-center gap-2 rounded-lg bg-blue-500 px-6 py-3 duration-200 enabled:hover:opacity-75 disabled:bg-gray-500"
			onclick={onInstallFromFolder}
			disabled={disableButtons}
			title="Install plugin from local directory"
		>
			<img src="svgs/folder-solid.svg" alt="" class="h-6 w-6" />
			<span class="text-sm font-medium text-black">From Folder</span>
		</button>
		<button
			class="flex flex-col items-center gap-2 rounded-lg bg-emerald-500 px-6 py-3 duration-200 enabled:hover:opacity-75 disabled:bg-gray-500"
			onclick={updateAllPlugins}
			disabled={disableButtons}
			title="Update all plugins with updater URLs"
		>
			<img src="svgs/arrows-rotate-solid.svg" alt="" class="h-6 w-6" />
			<span class="text-sm font-medium text-black">Update All</span>
		</button>
	</div>

	<!-- URL Entry -->
	{#if showURLEntry}
		<div class="mt-4">
			<label for="plugin-updater-url-input">URL:</label>
			<textarea
				rows="1"
				id="plugin-updater-url-input"
				class="w-[50%] max-w-[60%] resize-x rounded border-2 border-slate-300 bg-slate-100 text-slate-950 dark:border-slate-800"
				bind:value={textURLEntry}
			></textarea>
			<button
				title="Confirm"
				onclick={handleInstallFromURL}
				class="select-none rounded-sm bg-emerald-500 hover:opacity-75"
				><img src="svgs/check-solid.svg" class="h-5 w-5" alt="Confirm" /></button
			>
			<button
				title="Close URL entry"
				onclick={() => {
					showURLEntry = false;
					textURLEntry = '';
				}}
				class="select-none rounded-sm bg-rose-500 hover:opacity-75"
				><img src="svgs/xmark-solid.svg" class="h-5 w-5" alt="Close" /></button
			>
		</div>
	{/if}
</div>
