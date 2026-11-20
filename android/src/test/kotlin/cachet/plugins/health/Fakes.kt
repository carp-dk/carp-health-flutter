package cachet.plugins.health

import java.lang.reflect.Proxy

/**
 * An implementation of the interface [T] whose methods return what [answer] returns for the method's
 * name (a property's getter, e.g. "getFeatures", for a property). Suspend functions return at once,
 * without suspending. [answer] may throw unchecked exceptions only, as the proxy wraps checked ones.
 */
internal inline fun <reified T : Any> fakeOf(crossinline answer: (method: String) -> Any?): T =
    Proxy.newProxyInstance(T::class.java.classLoader, arrayOf(T::class.java)) { _, method, _ ->
        answer(method.name)
    } as T
