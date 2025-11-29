<script lang="ts">
	import Modal from '$lib/Components/CommonUI/Modal.svelte';
	import { bolt } from '$lib/State/Bolt';
	import { BoltService } from '$lib/Services/BoltService';
	import { requestNewClientListPromise } from '$lib/Util/Functions';
	import {
		type PluginConfig,
		type PluginMeta,
		type PluginUpdaterConfig
	} from '$lib/Util/Interfaces';
	import { clientList } from '$lib/Util/Store';
	import { GlobalState } from '$lib/State/GlobalState';

	let modal: Modal;

	let messageText: string | null = $state(null);
	let messageIsError: boolean = $state(false);
	let pluginList: { [key: string]: PluginMeta } = $state(bolt.pluginConfig);

	const platformFileSep: string = bolt.platform === 'windows' ? '\\' : '/';
	const configFileName: string = 'bolt.json';
	const sepConfigFileName: string = platformFileSep.concat(configFileName);
	const defaultMainLuaFilename: string = 'main.lua';

	export function open() {
		showURLEntry = false;
		modal.open();
	}

	const close = () => {
		bolt.pluginConfig = pluginList;
		BoltService.savePluginConfig();
	};

	// sets the info message to some white text
	const setMessageInfo = (msg: string) => {
		console.log(msg);
		messageText = msg;
		messageIsError = false;
	};

	// sets the info message to some red error text
	const setMessageError = (msg: string) => {
		console.error(msg);
		messageText = msg;
		messageIsError = true;
	};

	// creates a PluginConfig from a path to a bolt.json manifest,
	// usually an absolute path created by a filepicker
	const getPluginConfigPromiseByPath = (dirpath: string): Promise<PluginConfig | null> => {
		const path: string = dirpath.concat(
			dirpath.endsWith(platformFileSep) ? configFileName : sepConfigFileName
		);
		return fetch('/read-json-file?'.concat(new URLSearchParams({ path }).toString())).then((x) => {
			if (!x.ok) {
				setMessageError(`couldn't get plugin config: ${x.status}: ${x.statusText}`);
				return null;
			}
			return x.json().then((text) => <PluginConfig>text);
		});
	};

	// creates a PluginConfig from the ID of an installed plugin, assuming it was
	// installed from the URL and therefore is in a bolt-managed directory.
	// if it was installed from a user-managed location (i.e. PluginMeta.path exists),
	// this function will return null, so use getPluginConfigPromiseFromID instead.
	const getPluginConfigPromiseFromDataDir = (id: string): Promise<PluginConfig | null> => {
		return fetch('/get-plugindir-json?'.concat(new URLSearchParams({ id }).toString())).then(
			(x) => {
				if (!x.ok) return null;
				return x.json();
			}
		);
	};

	// creates a PluginConfig from the ID of an installed plugin
	const getPluginConfigPromiseByID = async (id: string): Promise<PluginConfig | null> => {
		const meta = pluginList[id];
		if (!meta) return null;
		const path = meta.path;
		if (path) return getPluginConfigPromiseByPath(path);
		return getPluginConfigPromiseFromDataDir(id);
	};

	// creates a new unique plugin ID
	const getNewPluginID = () => {
		const ids = Object.keys(pluginList);
		let id;
		do {
			id = crypto.randomUUID();
		} while (ids.includes(id));
		return id;
	};

	const unnamedPluginName = '(unnamed)';
	const unnamedClientName = '(new character)';

	// tries to configure a new plugin from a file path to a bolt.json manifest
	const addPluginFromPath = async (folderPath: string) => {
		try {
			const plugin = await getPluginConfigPromiseByPath(folderPath);
			if (!plugin) return; // if this returns null, error message was already set
			selectedPlugin = getNewPluginID();
			pluginList[selectedPlugin] = {
				name: plugin.name ?? unnamedPluginName,
				path: folderPath,
				version: plugin.version
			};
			bolt.pluginConfig = pluginList;
			GlobalState.pluginConfigHasPendingChanges = true;
		} catch {
			setMessageError("can't install plugin: unhandled exception");
		}
	};

	let disableButtons: boolean = $state(false);

	// tries to configure a new plugin from an updater URL
	const addPluginFromUpdaterURL = async (url: string) => {
		disableButtons = true;
		try {
			setMessageInfo('downloading...');
			const metaUrlResponse = await fetch(url);
			if (!metaUrlResponse) return;
			const config = await metaUrlResponse.json();

			if (!config.url) {
				setMessageError("can't install plugin: no download URL");
				return;
			}

			const configUrlResponse = await fetch(config.url);
			if (!configUrlResponse.ok) {
				setMessageError(
					`can't install plugin: remote download URL returned ${configUrlResponse.status}: ${configUrlResponse.statusText}`
				);
				return;
			}
			const data = await configUrlResponse.arrayBuffer();
			if (config.sha256) {
				const hash = await crypto.subtle.digest('SHA-256', data);
				const hashStr = Array.from(new Uint8Array(hash))
					.map((x) => x.toString(16).padStart(2, '0'))
					.join('');
				if (config.sha256 !== hashStr) {
					setMessageError("can't install plugin: incorrect file hash");
					return;
				}
			}

			const id = getNewPluginID();
			const r = await fetch('/install-plugin?'.concat(new URLSearchParams({ id }).toString()), {
				method: 'POST',
				body: data
			});
			if (!r.ok) {
				setMessageError(`can't install plugin: ${r.statusText}`);
				return;
			}
			const plugin = await getPluginConfigPromiseFromDataDir(id);
			if (!plugin) {
				setMessageError(`can't install plugin: ${configFileName} not found`);
				return;
			}

			selectedPlugin = id;
			pluginList[selectedPlugin] = {
				name: plugin.name ?? unnamedPluginName,
				version: plugin.version,
				updaterURL: url,
				sha256: config.sha256
			};
			bolt.pluginConfig = pluginList;
			GlobalState.pluginConfigHasPendingChanges = true;
			setMessageInfo(`plugin '${plugin.name}' installed`);
		} catch {
			setMessageError("can't install plugin: unhandled exception");
		} finally {
			disableButtons = false;
		}
	};

	// shows the user a file picker for .json files which will attempt to add
	// a plugin using the manifest that the user selects, if any
	const jsonFilePicker = () => {
		disableButtons = true;
		fetch('/json-file-picker')
			.then(async (x) => {
				// note this function won't be called until the user selects a file (or not),
				// so the request can take a very long time to return.
				if (!x.ok) {
					setMessageError(`file picker error: ${x.status}: ${x.statusText}`);
					return;
				}
				if (x.status !== 200) {
					// usually indicates that the user closed the file select
					return;
				}

				const text = await x.text();
				if (!text.endsWith(sepConfigFileName)) {
					setMessageError(`selection '${text}' is not named ${configFileName}; ignored`);
					return;
				}
				const subpath: string = text.substring(0, text.length - configFileName.length);
				addPluginFromPath(subpath);
			})
			.finally(() => (disableButtons = false));
	};

	// starts the plugin identified by `id` for the client identified by `client`
	const startPlugin = (client: number, id: string, path: string | null, main: string) => {
		const params: Record<string, string> = { client: client.toString(), id, main };
		if (path) {
			const pathWithCorrectSeps: string =
				bolt.platform === 'windows' ? path.replaceAll('\\', '/') : path;
			params.path = pathWithCorrectSeps.endsWith(platformFileSep)
				? pathWithCorrectSeps
				: pathWithCorrectSeps.concat('/');
		}
		fetch('/start-plugin?'.concat(new URLSearchParams(params).toString())).then((x) => {
			requestNewClientListPromise();
			if (!x.ok) {
				setMessageError(`couldn't start plugin: ${x.status}: ${x.statusText}`);
			}
		});
	};

	// stops the plugin identified by the client ID and plugin activation ID
	const stopPlugin = (client: number, uid: number) => {
		fetch(
			'/stop-plugin?'.concat(
				new URLSearchParams({ client: client.toString(), uid: uid.toString() }).toString()
			)
		).then((x) => {
			requestNewClientListPromise();
			if (!x.ok) {
				setMessageError(`couldn't stop plugin: ${x.status}: ${x.statusText}`);
			}
		});
	};

	// update a plugin by downloading the contents of its updater URL and checking for a new version.
	// assumes there's an updater URL for this plugin
	const updatePlugin = async (meta: PluginMeta, id: string) => {
		const url: string = <string>meta.updaterURL;
		const x = await fetch(url);
		if (!x.ok) {
			setMessageError(`can't update plugin: updater URL returned ${x.status}: ${x.statusText}`);
			return;
		}

		let config: PluginUpdaterConfig = await x.json();
		if (!config.url) {
			setMessageInfo(`can't update plugin '${meta.name}': no remote download URL is configured`);
			return;
		}

		let downloadNeeded = false;
		if (config.sha256) {
			if (meta.sha256 !== config.sha256) {
				downloadNeeded = true;
			}
		} else if (config.version) {
			if (meta.version !== config.version) {
				downloadNeeded = true;
			}
		}

		if (!downloadNeeded) {
			setMessageInfo(`plugin '${meta.name}' is already up-to-date`);
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
				setMessageError(`can't update plugin '${meta.name}': incorrect file hash`);
				return;
			}
		}
		fetch('/install-plugin?'.concat(new URLSearchParams({ id }).toString()), {
			method: 'POST',
			body: data
		});
		const plugin = await getPluginConfigPromiseFromDataDir(id);
		if (!plugin) {
			setMessageError(`can't update plugin '${meta.name}': ${configFileName} not found`);
			return;
		}
		if (config.sha256) meta.sha256 = config.sha256;
		if (plugin.name) meta.name = plugin.name;
		if (plugin.version) meta.version = plugin.version;
		GlobalState.pluginConfigHasPendingChanges = true;
		setMessageInfo(`plugin '${plugin.name}' updated`);
	};

	// get connected client list - the UI can be re-opened while clients are already running
	requestNewClientListPromise();

	// plugin management interface - currently-selected plugin
	var selectedPlugin: string = $state('');

	const openAboutPlugins = () =>
		fetch('/open-external-url', { method: 'POST', body: 'https://bolt.adamcake.com/plugins' });

	// connected clients list
	var isClientSelected: boolean = $state(false);
	var selectedClientId: number = $state(0);

	let showURLEntry: boolean = $state(false);
	let textURLEntry: string = $state('');
	$effect(() => {
		if (!$clientList.some((x) => x.uid === selectedClientId)) {
			isClientSelected = false;
		}
	});
	let selectedPluginMeta = $derived(pluginList[selectedPlugin]);

	// the PluginConfig of the plugin currently selected in the dropdown
	let managementPluginPromise: Promise<PluginConfig | null> | null = $derived(
		getPluginConfigPromiseByID(selectedPlugin)
	);
	let managementPlugin: PluginConfig | null = $state(null);
	$effect(() => {
		if (!managementPluginPromise) {
			managementPlugin = null;
			return;
		}
		managementPluginPromise.then((x) => {
			if (!x) return;
			managementPlugin = x;

			// if the name in bolt.json has been changed, update it in the PluginMeta and our plugin config file
			let dirty = false;
			if (x.name !== selectedPluginMeta.name) {
				selectedPluginMeta.name = x.name;
				dirty = true;
			}
			if (x.version !== selectedPluginMeta.version) {
				selectedPluginMeta.version = x.version;
				dirty = true;
			}
			if (dirty) {
				selectedPluginMeta = selectedPluginMeta;
				GlobalState.pluginConfigHasPendingChanges = true;
			}
		});
	});
	let selectedPluginPath = $derived(selectedPluginMeta && selectedPluginMeta.path);
	$effect(() => {
		if (selectedPluginMeta) {
			console.log(
				`${selectedPluginMeta.name} ${selectedPluginMeta.updaterURL} ${selectedPluginPath}`
			);
		}
	});
</script>

<Modal bind:this={modal} class="h-[90%] w-[90%] text-center" onClose={close}>
	<div
		class="left-0 float-left h-full w-[min(180px,_50%)] overflow-hidden border-r-2 border-slate-300 pt-2 dark:border-slate-800"
	>
		<button
			class="mx-auto mb-2 w-[95%] select-none rounded-lg border-2 {isClientSelected
				? 'border-blue-500 text-black dark:text-white'
				: 'border-black bg-blue-500 text-black'} p-2 font-bold hover:opacity-75"
			onclick={() => (isClientSelected = false)}
		>
			Manage Plugins
		</button>
		<hr class="p-1 dark:border-slate-700" />
		{#each $clientList as client}
			<button
				onclick={() => {
					selectedClientId = client.uid;
					isClientSelected = true;
					showURLEntry = false;
					textURLEntry = '';
					messageText = null;
				}}
				class="m-1 h-[28px] w-[95%] select-none rounded-lg border-2 {isClientSelected &&
				selectedClientId === client.uid
					? 'border-black bg-blue-500 text-black'
					: 'border-blue-500 text-black dark:text-white'} hover:opacity-75"
			>
				{client.identity || unnamedClientName}
			</button>
			<br />
		{/each}
		{#if $clientList.length == 0}
			<p>(start an RS3 game client with plugins enabled and it will be listed here.)</p>
		{/if}
	</div>
	<div class="h-full pt-10">
		{#if bolt.hasBoltPlugins}
			<select
				bind:value={selectedPlugin}
				class="mx-auto mb-4 w-[min(280px,_45%)] cursor-pointer rounded-lg border-2 border-slate-300 bg-inherit p-2 text-inherit duration-200 hover:opacity-75 dark:border-slate-800"
				onchange={() => (messageText = null)}
			>
				{#each Object.entries(pluginList) as [id, plugin]}
					<option class="dark:bg-slate-900" value={id}>{plugin.name ?? unnamedPluginName}</option>
				{/each}
			</select>
			{#if !isClientSelected}
				<span class="align-middle">
					<button
						class="mx-1 aspect-square w-9 select-none rounded-md bg-blue-500 p-1 text-[20px] font-bold duration-200 enabled:hover:opacity-75 disabled:bg-gray-500"
						onclick={() => {
							showURLEntry = !showURLEntry;
							textURLEntry = '';
						}}
						disabled={!bolt.hasLibArchive || disableButtons}
						title="Install plugin from updater URL"
					>
						<img src="svgs/download-solid.svg" alt="Install plugin from updater URL" />
					</button>
					<button
						class="aspect-square w-9 select-none rounded-md bg-blue-500 p-1 text-[20px] font-bold duration-200 enabled:hover:opacity-75 disabled:bg-gray-500"
						onclick={jsonFilePicker}
						disabled={disableButtons}
						title="Install plugin from local directory"
					>
						<img src="svgs/folder-solid.svg" alt="Install plugin from local directory" />
					</button>
				</span>
				<br />
				{#if showURLEntry}
					<label for="plugin-updater-url-input">URL:</label>
					<textarea
						rows="1"
						id="plugin-updater-url-input"
						class="w-[50%] max-w-[60%] resize-x rounded border-2 border-slate-300 bg-slate-100 text-slate-950 dark:border-slate-800"
						bind:value={textURLEntry}
					></textarea>
					<button
						title="Confirm"
						onclick={() => {
							addPluginFromUpdaterURL(textURLEntry);
							showURLEntry = false;
							textURLEntry = '';
						}}
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
					<br /><br />
				{/if}
				{#if Object.keys(pluginList).includes(selectedPlugin) && managementPluginPromise !== null}
					{#if managementPlugin}
						<p class="pb-4 text-xl font-bold">
							{managementPlugin.name ?? unnamedPluginName}
							{#if managementPlugin.version}
								<br />
								<span class="pb-4 text-xl font-bold italic text-slate-600">
									v{managementPlugin.version}
								</span>
							{/if}
						</p>
						<p class={managementPlugin.description ? null : 'italic'}>
							{managementPlugin.description ?? 'no description'}
						</p>
						<br />
					{/if}
					<button
						class="mx-auto mb-1 w-[min(144px,_25%)] select-none rounded-lg bg-blue-500 p-2 font-bold text-black duration-200 hover:opacity-75"
						onclick={() => {
							const path = pluginList[selectedPlugin].path;
							if (path) {
								fetch('/browse-directory?'.concat(new URLSearchParams({ path }).toString()));
							} else {
								fetch(
									'/browse-plugin-data?'.concat(
										new URLSearchParams({ id: selectedPlugin }).toString()
									)
								);
							}
						}}
					>
						Browse data
					</button>
					&nbsp;
					<button
						class="mx-auto mb-1 w-[min(144px,_25%)] select-none rounded-lg bg-blue-500 p-2 font-bold text-black duration-200 hover:opacity-75"
						onclick={() =>
							fetch(
								'/browse-plugin-config?'.concat(
									new URLSearchParams({ id: selectedPlugin }).toString()
								)
							)}
					>
						Browse config
					</button>
					<br />
					{#if selectedPluginMeta.updaterURL}
						<button
							class="m-1 mx-auto w-[min(144px,_25%)] select-none rounded-lg p-2 font-bold text-black duration-200 enabled:bg-blue-500 enabled:hover:opacity-75 disabled:bg-gray-500"
							onclick={() => updatePlugin(selectedPluginMeta, selectedPlugin)}
						>
							Check updates
						</button>
						&nbsp;
					{/if}
					<button
						class="m-1 mx-auto w-[min(144px,_25%)] select-none rounded-lg p-2 font-bold text-black duration-200 enabled:bg-rose-500 enabled:hover:opacity-75 disabled:bg-gray-500"
						onclick={() => {
							managementPluginPromise = null;
							GlobalState.pluginConfigHasPendingChanges = true;
							const meta = pluginList[selectedPlugin];
							if (meta) {
								fetch(
									'/uninstall-plugin?'.concat(
										new URLSearchParams({
											id: selectedPlugin,
											delete_data_dir: typeof meta.path === 'string' ? '0' : '1'
										}).toString()
									)
								);
								setMessageInfo(`plugin '${meta.name}' uninstalled`);
								delete pluginList[selectedPlugin];
							}
						}}
					>
						Remove
					</button>
				{/if}
				{#if Object.entries(pluginList).length === 0}
					<p>
						You have no plugins installed. You can install plugins either from an updater URL, or by
						downloading them onto your computer and selecting the "bolt.json" file.
					</p>
				{/if}
			{:else}
				<br />
				{#if managementPlugin}
					{#if managementPlugin && managementPlugin.main && Object.keys(pluginList).includes(selectedPlugin)}
						<button
							class="mx-auto mb-1 w-auto select-none rounded-lg bg-emerald-500 p-2 font-bold text-black duration-200 hover:opacity-75"
							onclick={() =>
								startPlugin(
									selectedClientId,
									selectedPlugin,
									selectedPluginPath ?? null,
									(managementPlugin && managementPlugin.main) ?? defaultMainLuaFilename
								)}
						>
							Start {managementPlugin.name}
						</button>
					{:else if Object.entries(pluginList).length === 0}
						<p>(no plugins installed)</p>
					{:else}
						<p>can't start plugin: does not appear to be configured</p>
					{/if}
					<br />
					<br />
					<hr class="p-1 dark:border-slate-700" />
					{#each $clientList as client}
						{#if client.uid === selectedClientId}
							{#each client.plugins as activePlugin}
								{#if Object.keys(pluginList).includes(activePlugin.id)}
									<p>
										{pluginList[activePlugin.id].name ?? activePlugin.id}
										<button
											class="select-none rounded-sm bg-rose-500 shadow-lg hover:opacity-75"
											onclick={() => {
												stopPlugin(selectedClientId, activePlugin.uid);
											}}
										>
											<img src="svgs/xmark-solid.svg" class="h-4 w-4" alt="Close" />
										</button>
									</p>
								{:else}
									<p>{activePlugin.id}</p>
								{/if}
							{/each}
						{/if}
					{/each}
				{/if}
			{/if}
		{/if}
		{#if messageText}
			<br /><br />
			{#if messageIsError}
				<p class="text-red-500">[error] {messageText}</p>
			{:else}
				<p>[info] {messageText}</p>
			{/if}
		{/if}
	</div>
	<div class="absolute bottom-2 right-4">
		<button
			class="m-0 cursor-pointer select-none border-none bg-transparent p-0 text-sm text-gray-500 underline"
			onclick={openAboutPlugins}>about plugins</button
		>
	</div>
</Modal>
