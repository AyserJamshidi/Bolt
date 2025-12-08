<script lang="ts">
	import Modal from '$lib/Components/CommonUI/Modal.svelte';
	import PluginList from './Plugin/PluginList.svelte';
	import PluginManagementList from './Plugin/PluginManagementList.svelte';
	import PluginManagementDetail from './Plugin/PluginManagementDetail.svelte';
  import PluginInstallBar from './Plugin/PluginInstallBar.svelte';
	import { bolt } from '$lib/State/Bolt';
	import { BoltService } from '$lib/Services/BoltService';
	import { requestNewClientListPromise } from '$lib/Util/Functions';
	import {
		type PluginConfig,
		type PluginMeta,
	} from '$lib/Util/Interfaces';
	import { clientList } from '$lib/Util/Store';
	import { GlobalState } from '$lib/State/GlobalState';

  const { config } = GlobalState

	let modal: Modal;

	let messageText: string | null = $state(null);
	let messageIsError: boolean = $state(false);
  let pluginList: { [key: string]: PluginMeta } = $state(bolt.pluginConfig);
	let accounts = $derived(BoltService.findSession($config.selected.user_id)?.accounts ?? []);


	const platformFileSep: string = bolt.platform === 'windows' ? '\\' : '/';
	const configFileName: string = 'bolt.json';
	const sepConfigFileName: string = platformFileSep.concat(configFileName);

  function getAccountNameById(id?: string): string {
    if (!id)  return unnamedClientName

    return accounts.find(v => {
      return v.accountId == id
    })?.displayName || unnamedClientName
  }

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
	const getPluginConfigPromiseByPath = async (dirpath: string): Promise<PluginConfig | null> => {
		const path: string = dirpath.concat(
			dirpath.endsWith(platformFileSep) ? configFileName : sepConfigFileName
		);
		const x = await fetch('/read-json-file?'.concat(new URLSearchParams({ path }).toString()));
		if (!x.ok) {
			setMessageError(`couldn't get plugin config: ${x.status}: ${x.statusText}`);
			return null;
		}
		const text = await x.json();
		return <PluginConfig>text;
	};

	// creates a PluginConfig from the ID of an installed plugin, assuming it was
	// installed from the URL and therefore is in a bolt-managed directory.
	// if it was installed from a user-managed location (i.e. PluginMeta.path exists),
	// this function will return null, so use getPluginConfigPromiseFromID instead.
	const getPluginConfigPromiseFromDataDir = async (id: string): Promise<PluginConfig | null> => {
		const x = await fetch('/get-plugindir-json?'.concat(new URLSearchParams({ id }).toString()));
		if (!x.ok) {
      setMessageError(`Couldn't load plugin config: ${x.status} ${x.statusText}`)
      return null;
    }
		return x.json();
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
  $effect(() => {
    if ($clientList.length > 0 && !selectedClientId) {
      selectedClientId = $clientList[0].uid
      isClientSelected = true
    }
  })


	let selectedPluginMeta = $derived(pluginList[selectedPlugin]);

	// the PluginConfig of the plugin currently selected
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

  // Track which clients we've already auto-started plugins for
  let autostartedClients = new Set<number>();

	const startPlugin = async (client: number, id: string, path: string | null, main: string) => {
		const params: Record<string, string> = { client: client.toString(), id, main };
		if (path) {
			const pathWithCorrectSeps = path.replaceAll('\\', '/');
			params.path = pathWithCorrectSeps.endsWith('/') ? pathWithCorrectSeps : pathWithCorrectSeps + '/';
		}
		const response = await fetch('/start-plugin?' + new URLSearchParams(params).toString());
		requestNewClientListPromise()
		if (!response.ok) {
			setMessageError(`couldn't start plugin: ${response.status}: ${response.statusText}`);
		}
	};

  // Watch for new clients and autostart their plugins
  $effect(() => {
    $clientList.forEach(client => {
      if (autostartedClients.has(client.uid)) return;
      if (!client.identity || !bolt.autostart[client.identity]) return;
      
      const pluginsToStart = bolt.autostart[client.identity];
      if (pluginsToStart.length === 0) return;
      
      autostartedClients.add(client.uid);
      
      // TBD: adding a timeout to wait for client to be read
      setTimeout(async () => {
      await Promise.all(
        pluginsToStart.map(async (pluginId) => {
          const meta = pluginList[pluginId];
          if (meta) {
            const config = await getPluginConfigPromiseByID(pluginId);
            await startPlugin(client.uid, pluginId, meta.path || null, config?.main ?? "main.lua");
          } else {
            console.warn(`Autostart plugin ${pluginId} not found in plugin list`);
          }
        })
      );
    }, 2000);
    });
    
    // Clean up Set when clients disconnect
    const currentClientIds = new Set($clientList.map(c => c.uid));
    autostartedClients = new Set([...autostartedClients].filter(id => currentClientIds.has(id)));
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
				{getAccountNameById(client.identity)}
			</button>
			<br />
		{/each}
		{#if $clientList.length == 0}
      <p class="px-2 text-xs italic text-slate-500 dark:text-slate-400">
        (start an RS3 game client with plugins enabled and it will be listed here.)
      </p>
		{/if}
	</div>
	<div class="flex h-full flex-col pt-2">
		{#if bolt.hasBoltPlugins}
      <PluginInstallBar
          hasLibArchive={bolt.hasLibArchive}
          {pluginList}
          onInstallFromURL={addPluginFromUpdaterURL}
          onInstallFromFolder={jsonFilePicker}
          {getPluginConfigPromiseFromDataDir}
          {setMessageInfo}
          {setMessageError}
        />

        {#if !isClientSelected}
				<!-- Two-column layout for plugin management -->
				<div class="flex flex-1 overflow-hidden">
					<!-- Left: Plugin list -->
					<div class="w-64">
						<PluginManagementList
							{pluginList}
							selectedPluginId={selectedPlugin}
							onSelectPlugin={(id: string) => {
								selectedPlugin = id;
								messageText = null;
							}}
						/>
					</div>

					<!-- Right: Plugin details -->
					<div class="flex-1 overflow-y-auto">
						{#if selectedPlugin }
							<PluginManagementDetail
								pluginId={selectedPlugin}
								pluginMeta={selectedPluginMeta}
								pluginConfig={managementPlugin}
								onRemove={() => {
									delete pluginList[selectedPlugin];
									pluginList = pluginList;
									selectedPlugin = '';
									managementPluginPromise = null;
								}}
								onUpdate={async () => {
									managementPluginPromise = getPluginConfigPromiseByID(selectedPlugin);
								}}
								{setMessageInfo}
								{setMessageError}
							/>
						{:else if Object.keys(pluginList).length === 0}
							<div class="flex h-full items-center justify-center p-6">
								<p class="text-center">
									You have no plugins installed. Use the buttons above to install plugins.
								</p>
							</div>
						{:else}
							<div class="flex h-full items-center justify-center p-6">
								<p class="text-slate-600 dark:text-slate-400">Select a plugin to view details</p>
							</div>
						{/if}
					</div>
				</div>
			{:else}
				<!-- Client plugin list -->
				<PluginList
					clientId={selectedClientId}
          accountID={$clientList.find(c => c.uid === selectedClientId)?.identity}
					{pluginList}
					activePlugins={$clientList.find((c) => c.uid === selectedClientId)?.plugins ?? []}
					onError={setMessageError}
					onRefresh={() => requestNewClientListPromise()}
          {startPlugin}
				/>
			{/if}
		{/if}
		{#if messageText}
			<div class="mt-4">
				{#if messageIsError}
					<p class="text-red-500">[error] {messageText}</p>
				{:else}
					<p>[info] {messageText}</p>
				{/if}
			</div>
		{/if}
	</div>
	<div class="absolute bottom-2 right-4">
		<button
			class="m-0 cursor-pointer select-none border-none bg-transparent p-0 text-sm text-gray-500 underline"
			onclick={openAboutPlugins}>about plugins</button
		>
	</div>
</Modal>
