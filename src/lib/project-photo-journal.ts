export type ProjectPhoto = {
  id: string;
  projectId: string;
  instructionPosition: number;
  section: string;
  capturedAt: string;
  image: Blob;
};

const databaseName = "stitchly-private-journal";
const storeName = "photos";

function database(): Promise<IDBDatabase> {
  return new Promise<IDBDatabase>((resolve, reject) => {
    const request = indexedDB.open(databaseName, 1);
    request.onupgradeneeded = () => {
      if (!request.result.objectStoreNames.contains(storeName)) request.result.createObjectStore(storeName, { keyPath: "id" });
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function transaction<T>(mode: IDBTransactionMode, action: (store: IDBObjectStore) => IDBRequest<T>): Promise<T> {
  const db = await database();
  return new Promise<T>((resolve, reject) => {
    const request = action(db.transaction(storeName, mode).objectStore(storeName));
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  }).finally(() => db.close());
}

export function photosForStep(photos: ProjectPhoto[], projectId: string, instructionPosition: number) {
  return photos.filter((photo) => photo.projectId === projectId && photo.instructionPosition === instructionPosition).sort((a, b) => b.capturedAt.localeCompare(a.capturedAt));
}

export async function loadStepPhotos(projectId: string, instructionPosition: number): Promise<ProjectPhoto[]> {
  if (typeof indexedDB === "undefined") return [];
  const photos = await transaction<ProjectPhoto[]>("readonly", (store) => store.getAll());
  return photosForStep(photos, projectId, instructionPosition);
}

export async function saveStepPhoto(input: Omit<ProjectPhoto, "id" | "capturedAt">): Promise<ProjectPhoto> {
  const photo: ProjectPhoto = { ...input, id: crypto.randomUUID(), capturedAt: new Date().toISOString() };
  await transaction<IDBValidKey>("readwrite", (store) => store.put(photo));
  return photo;
}

export async function deleteStepPhoto(id: string): Promise<void> {
  await transaction<undefined>("readwrite", (store) => store.delete(id));
}
