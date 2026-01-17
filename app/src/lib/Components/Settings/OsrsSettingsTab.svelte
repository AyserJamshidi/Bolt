<script lang="ts">
	import { BoltService } from '$lib/Services/BoltService';
	import { GlobalState } from '$lib/State/GlobalState';
	import { launchRuneLite } from '$lib/Util/Functions';

	const { config } = GlobalState;

	let selectedSession = $derived(BoltService.findSession($config.selected.user_id));
	let selectedAccount = $derived(
		BoltService.findAccount(
			selectedSession?.accounts ?? [],
			$config.userDetails[$config.selected.user_id ?? '']?.account_id
		)
	);

	let currentlyPickingFile = $state(false);

	async function openFilePicker() {
		currentlyPickingFile = true;
		$config.runelite_custom_jar = await BoltService.openFilePicker();
		console.log('done picking');
		currentlyPickingFile = false;
	}
</script>

<button
	class="p-2 mb-5 rounded-lg text-black text-sm bg-blue-500 opacity-50 enabled:cursor-pointer enabled:duration-200 enabled:opacity-100 enabled:hover:opacity-75"
	onclick={() => launchRuneLite(null, null, null, true)}
>
	<div class="flex">
		<img
			src="svgs/external-link.svg"
			alt="Configure RuneLite"
			class="mr-2 w-4 h-4"
		/>
		Configure RuneLite
	</div>
</button>
<div class="mx-auto border-slate-300 p-1 dark:border-slate-800">
	<label for="use_custom_jar">Use custom RuneLite JAR: </label>
	<input
		id="use_custom_jar"
		type="checkbox"
		bind:checked={$config.runelite_use_custom_jar}
		class="ml-2"
	/>
</div>
<div class="mx-auto p-2" class:opacity-25={!$config.runelite_use_custom_jar}>
	<textarea
		class="h-10 rounded border-2 border-slate-300 bg-slate-100 text-slate-950 dark:border-slate-800 dark:bg-slate-900 dark:text-slate-50"
		disabled={!$config.runelite_use_custom_jar}
		bind:value={$config.runelite_custom_jar}
	></textarea>
	<br />
	<button
		class="px-2 py-1 mt-1 rounded-lg border-2 border-blue-500 duration-200 enabled:hover:opacity-75"
		disabled={currentlyPickingFile || !$config.runelite_use_custom_jar}
		onclick={() => {
			openFilePicker();
		}}
	>
		Select File</button
	>
</div>
<div class="p-1">
	<label for="osrs_custom_launch_command">OSRS launch command:</label>
	<br />
	<textarea
		id="osrs_custom_launch_command"
		class="resize-x rounded border-2 border-slate-300 bg-slate-100 text-slate-950 disabled:opacity-50 dark:border-slate-800 dark:bg-slate-900 dark:text-slate-50"
		rows="1"
		cols="35"
		placeholder={'%command%'}
		bind:value={$config.osrs_launch_command}
	></textarea>
</div>
<div class="p-1">
	<label for="runelite_custom_launch_command">RuneLite launch command:</label>
	<br />
	<textarea
		id="runelite_custom_launch_command"
		class="resize-x rounded border-2 border-slate-300 bg-slate-100 text-slate-950 disabled:opacity-50 dark:border-slate-800 dark:bg-slate-900 dark:text-slate-50"
		rows="1"
		cols="35"
		placeholder={'%command%'}
		bind:value={$config.runelite_launch_command}
	></textarea>
</div>
<div class="p-1">
	<label for="hdos_custom_launch_command">HDOS launch command:</label>
	<br />
	<textarea
		id="hdos_custom_launch_command"
		class="resize-x rounded border-2 border-slate-300 bg-slate-100 text-slate-950 disabled:opacity-50 dark:border-slate-800 dark:bg-slate-900 dark:text-slate-50"
		rows="1"
		cols="35"
		placeholder={'%command%'}
		bind:value={$config.hdos_launch_command}
	></textarea>
</div>
