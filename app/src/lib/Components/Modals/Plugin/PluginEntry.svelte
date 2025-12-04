<script lang="ts">
	import type { PluginMeta } from '$lib/Util/Interfaces';

	interface Props {
		pluginId: string;
		pluginMeta: PluginMeta;
		clientId: number;
		isActive: boolean;
		activePluginUid: number | null;
		mainFile: string | null;
		onError: (msg: string) => void;
		onRefresh: () => void;
	}

	let {
		pluginId,
		pluginMeta,
		clientId,
		isActive,
		activePluginUid,
		mainFile,
		onError,
		onRefresh
	}: Props = $props();

	const defaultMainLuaFilename = 'main.lua';

	const startPlugin = async (client: number, id: string, path: string | null, main: string) => {
		const params: Record<string, string> = { client: client.toString(), id, main };
		if (path) {
			const pathWithCorrectSeps = path.replaceAll('\\', '/');
			params.path = pathWithCorrectSeps.endsWith('/') ? pathWithCorrectSeps : pathWithCorrectSeps + '/';
		}
		const response = await fetch('/start-plugin?' + new URLSearchParams(params).toString());
		onRefresh();
		if (!response.ok) {
			onError(`couldn't start plugin: ${response.status}: ${response.statusText}`);
		}
	};

	const stopPlugin = async (client: number, uid: number | null) => {
    if (!uid) {
      return console.error("no plugin uid, cannot stop plugin")
    }
		const response = await fetch(
			'/stop-plugin?' + new URLSearchParams({ 
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
			startPlugin(
				clientId,
				pluginId,
				pluginMeta.path ?? null,
				mainFile ?? defaultMainLuaFilename
			);
		}
	};
</script>

<div class="flex items-center justify-between border-b border-slate-300 p-2 dark:border-slate-800">
	<div class="flex-1 text-left">
		<span class="font-medium">{pluginMeta.name}</span>
		{#if pluginMeta.version}
			<span class="ml-2 text-sm text-slate-600 dark:text-slate-400">v{pluginMeta.version}</span>
		{/if}
	</div>
	<label class="relative inline-flex cursor-pointer items-center">
		<input
			type="checkbox"
			checked={isActive}
			onchange={handleToggle}
			class="peer sr-only"
		/>
		<div
			class="peer h-6 w-11 rounded-full bg-gray-300 after:absolute after:left-[2px] after:top-[2px] after:h-5 after:w-5 after:rounded-full after:border after:border-gray-300 after:bg-white after:transition-all after:content-[''] peer-checked:bg-blue-500 peer-checked:after:translate-x-full peer-checked:after:border-white dark:bg-gray-700"
		></div>
	</label>
</div>
