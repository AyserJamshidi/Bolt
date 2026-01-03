<script lang="ts">
	import DisclaimerModal from '$lib/Components/Modals/DisclaimerModal.svelte';
	import Launch from '$lib/Components/Launch.svelte';
	import LogView from '$lib/Components/LogView.svelte';
	import MainLayout from '$lib/Components/MainLayout.svelte';
	import TopBar from '$lib/Components/TopBar.svelte';
	import News from '$lib/Components/News.svelte';
	import { logger } from '$lib/Util/Logger';
	import { GlobalState } from '$lib/State/GlobalState';

	const logs = logger.logs;
	let psa: string | null = null;
	const { config } = GlobalState;

	const mainClass = 'mt-16 grid h-full grid-flow-col grid-cols-2 sm:grid-cols-3';
	const mainClassNoNews = 'mt-16 grid h-full grid-flow-col grid-cols-3';
</script>

<MainLayout>
	<DisclaimerModal />
	<TopBar {psa}></TopBar>
	<div class={$config.fetch_rss_feeds ? mainClass : mainClassNoNews}>
		{#if $config.fetch_rss_feeds}
			<div class="col-span-1 sm:col-span-2">
				<News />
			</div>
			<div class="col-span-1 -ml-4">
				<Launch bind:psa></Launch>
			</div>
		{:else}
			<div class="col-span-1 col-start-2">
				<Launch bind:psa></Launch>
			</div>
		{/if}
	</div>
	<LogView logs={$logs} />
</MainLayout>
