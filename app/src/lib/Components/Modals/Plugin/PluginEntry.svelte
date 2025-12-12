<script lang="ts">
	import type { PluginMeta } from '$lib/Util/Interfaces';

	interface Props {
		pluginId: string;
		pluginMeta: PluginMeta;
		clientId: number;
		clientIdentity?: string;
		isActive: boolean;
		activePluginUid: number | null;
		isAutostart: boolean;
		mainFile: string | null;
		onError: (msg: string) => void;
		onRefresh: () => void;
		onAutostartChange: (pluginId: string, enabled: boolean) => void;
		startPlugin: (clientId: number, pluginId: string, path: string | null, main: string) => void;
	}

	let {
		pluginId,
		pluginMeta,
		clientId,
		clientIdentity,
		isActive,
		activePluginUid,
		isAutostart,
		mainFile,
		startPlugin,
		onError,
		onRefresh,
		onAutostartChange
	}: Props = $props();

	const defaultMainLuaFilename = 'main.lua';

	const stopPlugin = async (client: number, uid: number | null) => {
		if (uid === null) {
			return console.error('no plugin uid, cannot stop plugin');
		}
		const response = await fetch(
			'/stop-plugin?' +
				new URLSearchParams({
					client: client.toString(),
					uid: uid.toString()
				}).toString()
		);
		onRefresh();
		if (!response.ok) {
			onError(`couldn't stop plugin: ${response.status}: ${response.statusText}`);
		}
	};

	const handleToggle = () => {
		if (isActive) {
			stopPlugin(clientId, activePluginUid);
		} else {
			startPlugin(clientId, pluginId, pluginMeta.path ?? null, mainFile ?? defaultMainLuaFilename);
		}
	};

	const handleAutostartToggle = () => {
		if (clientIdentity) {
			onAutostartChange(pluginId, !isAutostart);
		}
	};
</script>

<div class="flex items-center justify-between border-b border-slate-300 p-2 dark:border-slate-800">
	<div class="text-left">
		<span class="font-medium">{pluginMeta.name}</span>
	</div>
	<div class="flex items-center gap-10">
		<!-- Autostart checkbox -->
		{#if clientIdentity}
			<button
				onclick={handleAutostartToggle}
				class="rounded-full px-3 py-1 text-xs font-medium transition-colors {isAutostart
					? 'bg-blue-500 text-white'
					: 'bg-slate-200 text-slate-600 dark:bg-slate-700 dark:text-slate-300'}"
			>
				Auto
			</button>
		{/if}
		<!-- Active toggle -->
		<label class="relative inline-flex cursor-pointer items-center">
			<input type="checkbox" checked={isActive} onchange={handleToggle} class="peer sr-only" />
			<div
				class="peer h-6 w-11 rounded-full bg-gray-300 after:absolute after:left-[2px] after:top-[2px] after:h-5 after:w-5 after:rounded-full after:border after:border-gray-300 after:bg-white after:transition-all after:content-[''] peer-checked:bg-blue-500 peer-checked:after:translate-x-full peer-checked:after:border-white dark:bg-gray-700"
			></div>
		</label>
	</div>
</div>
