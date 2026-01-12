<script lang="ts">
	interface NewsItem {
		title: string;
		imageUrl: string;
		url: string;
		date: string;
	}

	export let newsItem: NewsItem | undefined;
	export let loading: boolean = false;
</script>

<div>
	{#if loading}
		<div
			class="news-card block cursor-pointer overflow-hidden rounded-lg border border-slate-300 bg-transparent p-3 shadow-md duration-200 dark:border-slate-800 dark:bg-slate-900"
			style="aspect-ratio: 1 / 1;"
		>
			<div class="flex h-full flex-col">
				<div
					class="mb-2 h-5 w-3/4 animate-pulse rounded bg-slate-300/40 dark:bg-slate-800/40"
				></div>
				<div
					class="mb-2 h-1/2 w-full animate-pulse rounded bg-slate-300/40 dark:bg-slate-800/40"
				></div>
				<div class="mt-auto">
					<div class="h-4 w-1/3 animate-pulse rounded bg-slate-300/40 dark:bg-slate-800/40"></div>
				</div>
			</div>
		</div>
	{:else if newsItem}
		<a
			href={newsItem.url}
			target="_blank"
			rel="noopener noreferrer"
			class="news-card block cursor-pointer overflow-hidden rounded-lg border border-slate-300 bg-slate-100 p-3 shadow-md duration-200 hover:opacity-75 dark:border-slate-800 dark:bg-slate-900"
			style="aspect-ratio: 1 / 1;"
			onclick={(evt) => {
				evt.preventDefault();
				fetch('/open-external-url', { method: 'POST', body: newsItem.url });
			}}
		>
			<div class="flex h-full flex-col">
				<h2
					class="text-md mb-2 overflow-hidden font-semibold leading-tight text-slate-900 dark:text-slate-100"
					style="max-height:30%;"
				>
					{newsItem.title}
				</h2>
				<div class="flex-1"></div>
				<div class="mb-2 w-full overflow-hidden rounded" style="height:50%;">
					<img src={newsItem.imageUrl} alt={newsItem.title} class="h-full w-full object-cover" />
				</div>
				<div>
					<p class="text-sm text-slate-600 dark:text-slate-400">{newsItem.date}</p>
				</div>
			</div>
		</a>
	{/if}
</div>
