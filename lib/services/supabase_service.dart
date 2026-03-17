import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseService {
  SupabaseService(this.client);

  final SupabaseClient client;
  static const _uuid = Uuid();
  static final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};
  static const Duration _cacheTtl = Duration(seconds: 45);

  Future<List<Map<String, dynamic>>> fetchItems(String userId, {bool forceRefresh = false}) =>
      _cachedList(
        cacheKey: 'items:$userId',
        forceRefresh: forceRefresh,
        loader: () async {
          final response = await client
              .from('items')
              .select()
              .eq('user_id', userId)
              .order('created_at', ascending: false);
          return List<Map<String, dynamic>>.from(response);
        },
      );

  Future<List<Map<String, dynamic>>> fetchItemsWithListings(String userId, {bool forceRefresh = false}) =>
      _cachedList(
        cacheKey: 'items_with_listings:$userId',
        forceRefresh: forceRefresh,
        loader: () async {
          final response = await client
              .from('items')
              .select('*, listings(*)')
              .eq('user_id', userId)
              .order('created_at', ascending: false);
          return List<Map<String, dynamic>>.from(response);
        },
      );

  Future<void> createItem(Map<String, dynamic> data) async {
    await client.from('items').insert(data);
    _invalidatePrefixes(['items:', 'items_with_listings:']);
  }

  Future<void> updateItem(String id, Map<String, dynamic> data) async {
    await client.from('items').update(data).eq('id', id);
    _invalidatePrefixes(['items:', 'items_with_listings:']);
  }

  Future<void> deleteItem(String id) async {
    await client.from('items').delete().eq('id', id);
    _invalidatePrefixes(['items:', 'items_with_listings:']);
  }

  Future<List<Map<String, dynamic>>> fetchSales(String userId, {bool forceRefresh = false}) =>
      _cachedList(
        cacheKey: 'sales:$userId',
        forceRefresh: forceRefresh,
        loader: () async {
          final response = await client
              .from('sales')
              .select('*, items(*)')
              .eq('user_id', userId)
              .order('sold_date', ascending: false);
          return List<Map<String, dynamic>>.from(response);
        },
      );

  Future<List<Map<String, dynamic>>> fetchSalesWithListings(String userId, {bool forceRefresh = false}) =>
      _cachedList(
        cacheKey: 'sales_with_listings:$userId',
        forceRefresh: forceRefresh,
        loader: () async {
          final response = await client
              .from('sales')
              .select('*, listing:listings(*, item:items(*))')
              .eq('user_id', userId)
              .order('sold_date', ascending: false);
          return List<Map<String, dynamic>>.from(response);
        },
      );

  Future<void> createSale(Map<String, dynamic> data) async {
    await client.from('sales').insert(data);
    _invalidatePrefixes(['sales:', 'sales_with_listings:']);
  }

  Future<void> updateSale(String id, Map<String, dynamic> data) async {
    await client.from('sales').update(data).eq('id', id);
    _invalidatePrefixes(['sales:', 'sales_with_listings:']);
  }

  Future<void> deleteSale(String id) async {
    await client.from('sales').delete().eq('id', id);
    _invalidatePrefixes(['sales:', 'sales_with_listings:']);
  }

  Future<List<Map<String, dynamic>>> fetchListings(String userId, {bool forceRefresh = false}) =>
      _cachedList(
        cacheKey: 'listings:$userId',
        forceRefresh: forceRefresh,
        loader: () async {
          final response = await client
              .from('listings')
              .select('*, item:items(*)')
              .eq('user_id', userId)
              .order('created_at', ascending: false);
          return List<Map<String, dynamic>>.from(response);
        },
      );

  Future<void> createListing(Map<String, dynamic> data) async {
    await client.from('listings').insert(data);
    _invalidatePrefixes(['listings:', 'items_with_listings:', 'sales_with_listings:']);
  }

  Future<void> updateListing(String id, Map<String, dynamic> data) async {
    await client.from('listings').update(data).eq('id', id);
    _invalidatePrefixes(['listings:', 'items_with_listings:', 'sales_with_listings:']);
  }

  Future<void> deleteListing(String id) async {
    await client.from('listings').delete().eq('id', id);
    _invalidatePrefixes(['listings:', 'items_with_listings:', 'sales_with_listings:']);
  }

  Future<List<Map<String, dynamic>>> fetchItemStock(String userId, {bool forceRefresh = false}) =>
      _cachedList(
        cacheKey: 'item_stock:$userId',
        forceRefresh: forceRefresh,
        loader: () async {
          final response = await client
              .from('item_stock')
              .select('*, items(*)')
              .eq('user_id', userId)
              .order('updated_at', ascending: false);
          return List<Map<String, dynamic>>.from(response);
        },
      );

  Future<void> upsertItemStock(Map<String, dynamic> data) async {
    await client.from('item_stock').upsert(data, onConflict: 'item_id,size,user_id');
    _invalidatePrefixes(['item_stock:']);
  }

  Future<void> createItemStock(Map<String, dynamic> data) async {
    await client.from('item_stock').insert(data);
    _invalidatePrefixes(['item_stock:']);
  }

  Future<void> updateItemStock(String id, Map<String, dynamic> data) async {
    await client.from('item_stock').update(data).eq('id', id);
    _invalidatePrefixes(['item_stock:']);
  }

  Future<void> deleteItemStock(String id) async {
    await client.from('item_stock').delete().eq('id', id);
    _invalidatePrefixes(['item_stock:']);
  }

  Future<List<Map<String, dynamic>>> fetchPurchaseOrders(String userId) async {
    return fetchPurchases(userId);
  }

  Future<List<Map<String, dynamic>>> fetchPurchases(String userId, {bool forceRefresh = false}) =>
      _cachedList(
        cacheKey: 'purchases:$userId',
        forceRefresh: forceRefresh,
        loader: () async {
          final response = await client
              .from('purchases')
              .select()
              .eq('user_id', userId)
              .order('bought_date', ascending: false);
          return List<Map<String, dynamic>>.from(response);
        },
      );

  Future<List<Map<String, dynamic>>> fetchItemPurchases(String userId, {bool forceRefresh = false}) =>
      _cachedList(
        cacheKey: 'item_purchases:$userId',
        forceRefresh: forceRefresh,
        loader: () async {
          final response = await client
              .from('item_purchases')
              .select('*, item:items(*)')
              .eq('user_id', userId)
              .order('purchased_at', ascending: false)
              .order('created_at', ascending: false);
          return List<Map<String, dynamic>>.from(response);
        },
      );

  Future<void> createItemPurchase(Map<String, dynamic> data) async {
    await client.from('item_purchases').insert(data);
    _invalidatePrefixes(['item_purchases:']);
  }

  Future<void> updateItemPurchase(String id, Map<String, dynamic> data) async {
    await client.from('item_purchases').update(data).eq('id', id);
    _invalidatePrefixes(['item_purchases:']);
  }

  Future<void> deleteItemPurchase(String id) async {
    await client.from('item_purchases').delete().eq('id', id);
    _invalidatePrefixes(['item_purchases:']);
  }

  Future<Map<String, dynamic>> createPurchaseOrder(Map<String, dynamic> data) async {
    return createPurchase(data);
  }

  Future<Map<String, dynamic>> createPurchase(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    final id = payload['id'] as String?;
    if (id == null || id.isEmpty) {
      payload['id'] = _uuid.v4();
    }
    final response = await client.from('purchases').insert(payload).select().single();
    _invalidatePrefixes(['purchases:']);
    return Map<String, dynamic>.from(response);
  }

  Future<void> updatePurchaseOrder(String id, Map<String, dynamic> data) async {
    await updatePurchase(id, data);
  }

  Future<void> updatePurchase(String id, Map<String, dynamic> data) async {
    await client.from('purchases').update(data).eq('id', id);
    _invalidatePrefixes(['purchases:']);
  }

  Future<void> deletePurchaseOrder(String id) async {
    await deletePurchase(id);
  }

  Future<void> deletePurchase(String id) async {
    await client.from('purchases').delete().eq('id', id);
    _invalidatePrefixes(['purchases:']);
  }

  Future<List<Map<String, dynamic>>> fetchPurchaseDetails(String userId, {bool forceRefresh = false}) =>
      _cachedList(
        cacheKey: 'purchase_details:$userId',
        forceRefresh: forceRefresh,
        loader: () async {
          final response = await client
              .from('purchase_details')
              .select('*, items(*), purchases(*)')
              .eq('user_id', userId)
              .order('created_at', ascending: false);
          return List<Map<String, dynamic>>.from(response);
        },
      );

  Future<void> createPurchaseDetail(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    final id = payload['id'] as String?;
    if (id == null || id.isEmpty) {
      payload['id'] = _uuid.v4();
    }
    await client.from('purchase_details').insert(payload);
    _invalidatePrefixes(['purchase_details:']);
  }

  Future<void> updatePurchaseDetail(String id, Map<String, dynamic> data) async {
    await client.from('purchase_details').update(data).eq('id', id);
    _invalidatePrefixes(['purchase_details:']);
  }

  Future<void> deletePurchaseDetail(String id) async {
    await client.from('purchase_details').delete().eq('id', id);
    _invalidatePrefixes(['purchase_details:']);
  }

  Future<List<Map<String, dynamic>>> fetchItemCosts(String userId) async {
    final response = await client.from('item_costs').select().eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> importVinted(String url) async {
    final response = await client.functions.invoke('import-vinted', body: {'url': url});
    if (response.status != 200) {
      throw Exception(response.data);
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  static void clearCache() {
    _cache.clear();
  }

  Future<List<Map<String, dynamic>>> _cachedList({
    required String cacheKey,
    required Future<List<Map<String, dynamic>>> Function() loader,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final cached = _cache[cacheKey];
    if (!forceRefresh && cached != null && now.difference(cached.timestamp) <= _cacheTtl) {
      return _cloneRows(cached.rows);
    }

    final rows = await loader();
    _cache[cacheKey] = _CacheEntry(timestamp: now, rows: _cloneRows(rows));
    return _cloneRows(rows);
  }

  void _invalidatePrefixes(List<String> prefixes) {
    final keysToRemove = _cache.keys.where((key) => prefixes.any(key.startsWith)).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  List<Map<String, dynamic>> _cloneRows(List<Map<String, dynamic>> rows) {
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }
}

class _CacheEntry {
  const _CacheEntry({
    required this.timestamp,
    required this.rows,
  });

  final DateTime timestamp;
  final List<Map<String, dynamic>> rows;
}
