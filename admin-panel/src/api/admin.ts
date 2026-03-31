import apiClient from './client'

export const adminApi = {
  // Auth
  login: (email: string, password: string) =>
    apiClient.post('/auth/login', { email, password }),

  // Stats & Analytics
  getStats:     () => apiClient.get('/admin/stats'),
  getAnalytics: () => apiClient.get('/admin/analytics'),
  getSystem:    () => apiClient.get('/admin/system'),
  clearCache:   () => apiClient.post('/admin/system/clear-cache'),

  // Users
  getUsers: (params: { page?: number; limit?: number; search?: string; is_active?: boolean; is_admin?: boolean }) =>
    apiClient.get('/admin/users', { params }),
  getUserDetail:   (id: number)             => apiClient.get(`/admin/users/${id}`),
  getUserHistory:  (id: number, limit = 50) => apiClient.get(`/admin/users/${id}/history`, { params: { limit } }),
  toggleBlockUser: (id: number)             => apiClient.put(`/admin/users/${id}/block`),
  toggleAdminUser: (id: number)             => apiClient.put(`/admin/users/${id}/admin`),
  deleteUser:      (id: number)             => apiClient.delete(`/admin/users/${id}`),

  // Tracks
  getTracks:   (search?: string)   => apiClient.get('/admin/tracks', { params: search ? { search } : {} }),
  deleteTrack: (spotifyId: string) => apiClient.delete(`/admin/tracks/${spotifyId}`),

  // Playlists
  getPlaylists:      (params?: { visibility?: string; is_collaborative?: boolean }) =>
    apiClient.get('/admin/playlists', { params }),
  getPlaylistTracks: (id: number) => apiClient.get(`/admin/playlists/${id}/tracks`),
  deletePlaylist:    (id: number) => apiClient.delete(`/admin/playlists/${id}`),

  // Matches
  getMatches:  (params?: { sim_min?: number; sim_max?: number }) =>
    apiClient.get('/admin/matches', { params }),
  deleteMatch: (id: number) => apiClient.delete(`/admin/matches/${id}`),

  // Reports
  getReports:    ()           => apiClient.get('/admin/reports'),
  dismissReport: (id: number) => apiClient.delete(`/admin/reports/${id}`),

  // Rooms
  getRooms:  ()           => apiClient.get('/admin/rooms'),
  closeRoom: (id: number) => apiClient.delete(`/admin/rooms/${id}`),
}
