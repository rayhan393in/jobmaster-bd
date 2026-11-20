import data from './exam-taxonomy.json';
export const examTaxonomy=data;
export type TaxonomySubject=typeof data.subjects[number];
export function taxonomyLeaf(id:string){for(const subject of data.subjects)for(const topic of subject.topics){const leaf=topic.subtopics.find(l=>l.id===id);if(leaf)return {subject,topic,leaf};}return null;}
