<script lang="ts">
	interface NewsItem {
		title: string;
		imageUrl: string;
		url: string;
		date: string;
	}

	export let newsItem: NewsItem | undefined;
</script>

<div>
	{#if newsItem}
		<a
			href={newsItem.url}
			target="_blank"
			rel="noopener noreferrer"
			class="news-card block cursor-pointer overflow-hidden rounded-lg border border-slate-300 bg-slate-100 p-3 shadow-md duration-200 hover:opacity-75 dark:border-slate-800 dark:bg-slate-900"
			style="aspect-ratio: 1 / 1;"
		>
			<div class="flex h-full flex-col">
				<h2 class="text-md mb-2 font-semibold text-slate-900 dark:text-slate-100">
					{newsItem.title}
				</h2>
				<img
					src={newsItem.imageUrl}
					alt={newsItem.title}
					class="mb-2 h-1/2 w-full rounded object-cover"
				/>

				<div class="mt-auto">
					<p class="text-sm text-slate-600 dark:text-slate-400">{newsItem.date}</p>
				</div>
			</div>
		</a>
	{/if}
</div>
