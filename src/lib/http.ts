export async function readJson(response:Response){
 const text=await response.text();
 if(!response.headers.get('content-type')?.includes('application/json'))throw new Error(`সার্ভার থেকে সঠিক API response আসেনি (HTTP ${response.status})। JobMaster BD-এর Live Preview নতুন ট্যাবে খুলে আবার চেষ্টা করুন। ডাউনলোড করা HTML বা file preview থেকে লগইন কাজ করবে না।`);
 try{return JSON.parse(text);}catch{throw new Error('সার্ভারের উত্তর পড়া যায়নি। পেজ refresh করে আবার চেষ্টা করুন।');}
}
