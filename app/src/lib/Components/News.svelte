<script lang="ts">
	import { onMount } from 'svelte';
	import NewsCard from './CommonUI/NewsCard.svelte';
	import { GlobalState } from '$lib/State/GlobalState';
	import { Game } from '$lib/Util/Interfaces';

	const RSS_URL = 'aHR0cHM6Ly9zZWN1cmUucnVuZXNjYXBlLmNvbS9tPW5ld3MvbGF0ZXN0X25ld3MucnNz';
	const DECODED_RSS = atob(RSS_URL);
	const { config } = GlobalState;

	let newsItems: Array<{ title: string; imageUrl: string; url: string; date: string }> = [];

	const CACHE_KEY_OSRS = 'bolt:news:feed-osrs';
	const CACHE_TS_KEY_OSRS = 'bolt:news:feed:ts-osrs';
	const CACHE_KEY_RS3 = 'bolt:news:feed-rs3';
	const CACHE_TS_KEY_RS3 = 'bolt:news:feed:ts-rs3';
	const CACHE_TTL = 6 * 60 * 60 * 1000; // 6 hours

	const parseAndSet = (xmlString: string) => {
		const parser = new DOMParser();
		const xmlDoc = parser.parseFromString(xmlString, 'application/xml');
		const items = xmlDoc.getElementsByTagName('item');
		const parsed: Array<{ title: string; imageUrl: string; url: string; date: string }> = [];
		for (let i = 0; i < items.length; i++) {
			const item = items[i];
			const title = item.getElementsByTagName('title')[0]?.textContent || 'No Title';
			const url = item.getElementsByTagName('link')[0]?.textContent || '#';
			const rawDate = item.getElementsByTagName('pubDate')[0]?.textContent || '';
			let date = rawDate;
			// Format date to show only the date portion (e.g. "Tue, 16 Dec 2025")
			const dateObj = new Date(rawDate);
			if (!isNaN(dateObj.getTime())) {
				const parts = dateObj.toUTCString().split(' ');
				date = parts.slice(0, 4).join(' ');
			}
			const enclosure = item.getElementsByTagName('enclosure')[0];
			const imageUrl = enclosure ? enclosure.getAttribute('url') || '' : '';
			parsed.push({ title, imageUrl, url, date });
		}
		parsed.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
		newsItems = parsed;
	};

	export const fetchNews = async () => {
		const IS_OSRS = $config.selected.game === Game.osrs;
		const CACHE_KEY = IS_OSRS ? CACHE_KEY_OSRS : CACHE_KEY_RS3;
		const CACHE_TS_KEY = IS_OSRS ? CACHE_TS_KEY_OSRS : CACHE_TS_KEY_RS3;

		try {
			const now = Date.now();
			const rawCached = localStorage.getItem(CACHE_KEY);
			const cachedTs = parseInt(localStorage.getItem(CACHE_TS_KEY) || '0', 10);
			// Use cached if fresh
			if (rawCached && now - cachedTs < CACHE_TTL) {
				parseAndSet(rawCached);
				return;
			}

			// Otherwise fetch and cache
			let fetchUrl = DECODED_RSS;
			if (IS_OSRS) {
				fetchUrl += '?oldschool=1';
			}
			const response = await fetch(fetchUrl);
			const rssText = await response.text();

			// persist cache
			try {
				localStorage.setItem(CACHE_KEY, rssText);
				localStorage.setItem(CACHE_TS_KEY, String(now));
			} catch (e) {
				// localStorage may be full or unavailable; ignore caching errors
				console.warn('Unable to cache RSS feed:', e);
			}

			parseAndSet(rssText);
		} catch (error) {
			console.error('Error fetching or parsing RSS feed:', error);
			// fallback to cached data if available
			const rawCached = localStorage.getItem(CACHE_KEY_OSRS);
			if (rawCached) {
				parseAndSet(rawCached);
			}
		}
	};

	onMount(async () => {
		await fetchNews();
		config.subscribe(() => {
			fetchNews();
		});
	});
</script>

<div class="no-scrollbar max-h-[calc(80vh-6rem)] min-h-0 overflow-auto p-4">
	<div
		class="grid auto-rows-fr grid-cols-1 items-stretch gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
	>
		{#each newsItems as newsItem (newsItem.url)}
			<NewsCard {newsItem} />
		{/each}
	</div>
</div>

<style>
	/* Hide scrollbar for Chrome, Safari and Opera */
	.no-scrollbar::-webkit-scrollbar {
		display: none;
	}
	/* Hide scrollbar for IE, Edge and Firefox */
	.no-scrollbar {
		-ms-overflow-style: none; /* IE and Edge */
		scrollbar-width: none; /* Firefox */
	}
</style>
