<script lang="ts">
	import DisclaimerModal from '$lib/Components/Modals/DisclaimerModal.svelte';
	import Launch from '$lib/Components/Launch.svelte';
	import LogView from '$lib/Components/LogView.svelte';
	import MainLayout from '$lib/Components/MainLayout.svelte';
	import TopBar from '$lib/Components/TopBar.svelte';
	import News from '$lib/Components/News.svelte';
	import { logger } from '$lib/Util/Logger';
	import { GlobalState } from '$lib/State/GlobalState';
	import { Game } from '$lib/Util/Interfaces';

	const logs = logger.logs;
	let osrsPsa: string | null = null;
	let rs3Psa: string | null = null;
	const { config } = GlobalState;

	const mainClass = 'mt-16 grid h-full grid-flow-col grid-cols-2 sm:grid-cols-3';
	const mainClassNoNews = 'mt-16 grid h-full grid-flow-col grid-cols-3';
	const psaClass =
		'mb-5 w-full animate-pulse rounded border border-amber-500 bg-slate-100 p-2 shadow-md duration-200 dark:bg-slate-900';
</script>

<MainLayout>
	<DisclaimerModal />
	<TopBar />
	<div class={$config.fetch_rss_feeds ? mainClass : mainClassNoNews}>
		{#if $config.fetch_rss_feeds}
			<div class="col-span-1 sm:col-span-2">
				<News bind:osrsPsa bind:rs3Psa />
			</div>
			<div class="col-span-1 -ml-4">
				<Launch bind:osrsPsa bind:rs3Psa></Launch>
			</div>
		{:else if !$config.fetch_rss_feeds && $config.check_announcements}
			<div class="col-span-1 m-4">
				{#if osrsPsa && $config.selected.game === Game.osrs}
					<div class={psaClass}>
						{osrsPsa}
					</div>
				{:else if rs3Psa && $config.selected.game === Game.rs3}
					<div class={psaClass}>
						{rs3Psa}
					</div>
				{/if}
			</div>
			<div class="col-span-1 col-start-2">
				<Launch bind:osrsPsa bind:rs3Psa></Launch>
			</div>
		{:else}
			<div class="col-span-1 col-start-2">
				<Launch bind:osrsPsa bind:rs3Psa></Launch>
			</div>
		{/if}
	</div>
	<LogView logs={$logs} />
</MainLayout>
