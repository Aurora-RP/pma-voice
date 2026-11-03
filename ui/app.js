// Voice HUD: our mic and who is talking. Fed by client/ui.lua with one 'state' message whenever
// something changes; mic clicks come as { sound, volume }.

const MAX_TALKERS = 6;

const voice = document.getElementById('voice');
const talkersEl = document.getElementById('talkers');
const more = document.getElementById('more');
const me = document.getElementById('me');
const meLabel = document.getElementById('me-label');
const meSub = document.getElementById('me-sub');

const rows = new Map(); // id -> row element

function makeRow(t) {
	const row = document.createElement('div');
	row.className = 'talker';
	row.innerHTML = '<div class="bars"><i></i><i></i><i></i></div><span class="name"></span>';
	return row;
}

function setRadio(row, radio) {
	row.classList.toggle('radio', radio);
	let tag = row.querySelector('.radio-tag');
	if (radio && !tag) {
		tag = document.createElement('span');
		tag.className = 'radio-tag';
		tag.textContent = 'Radio';
		row.appendChild(tag);
	} else if (!radio && tag) {
		tag.remove();
	}
}

function renderTalkers(list) {
	const shown = list.slice(0, MAX_TALKERS);
	const keep = new Set(shown.map((t) => t.id));

	// Gone: fade out, then remove.
	for (const [id, row] of rows) {
		if (keep.has(id)) continue;
		rows.delete(id);
		row.classList.add('leaving');
		row.addEventListener('animationend', () => row.remove(), { once: true });
	}

	for (const t of shown) {
		let row = rows.get(t.id);
		if (!row) {
			row = makeRow(t);
			rows.set(t.id, row);
			talkersEl.appendChild(row);
		}
		row.querySelector('.name').textContent = t.name;
		setRadio(row, !!t.radio);
	}

	const extra = list.length - shown.length;
	more.classList.toggle('hidden', extra <= 0);
	more.textContent = extra > 0 ? `+${extra} more talking` : '';
}

function renderMe(d) {
	me.classList.toggle('muted', !!d.micOff);
	me.classList.toggle('talking', !!d.talking && !d.micOff);
	me.classList.toggle('radio', !!d.usingRadio);
	meLabel.textContent = d.label || '';
	meSub.textContent = d.sub || '';
}

function playClick(d) {
	const click = document.getElementById(d.sound);
	if (!click) return;
	click.load();
	click.volume = d.volume;
	// two clicks too fast reject the first play; nothing to do about it
	click.play().catch(() => {});
}

window.addEventListener('message', (event) => {
	const d = event.data;
	if (d.sound) {
		playClick(d);
		return;
	}
	if (d.action !== 'state') return;
	voice.classList.toggle('hidden', !d.visible);
	voice.classList.toggle('corner', !!d.corner);
	renderMe(d);
	renderTalkers(d.talkers || []);
});

fetch(`https://${GetParentResourceName()}/uiReady`, { method: 'POST', body: '{}' });
